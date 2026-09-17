<?php

namespace Tests\Feature\Products;

use App\Models\ProductColor;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use App\Models\User;
use App\Services\ProductVariantService;
use App\Services\ShipmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The product barcode on labels is digits only (some clients' systems reject
 * "TGC-00000042"), a valid EAN-13 in GS1's in-store range so it can't be
 * another manufacturer's number, and labels printed before the switch still
 * find their product.
 */
class ProductBarcodeTest extends TestCase
{
    use RefreshDatabase;

    public static function variantIds(): array
    {
        return [
            'first variant'         => [1, '2984200000016'],
            'double digits'         => [42, '2984200000429'],
            'a real one from prod'  => [5984, '2984200059847'],
            'largest that fits'     => [9_999_999, '2984299999994'],
        ];
    }

    #[DataProvider('variantIds')]
    public function test_barcode_is_a_valid_in_store_ean13_that_names_the_variant(int $id, string $expected): void
    {
        $barcode = ProductVariant::barcodeFor($id);

        $this->assertSame($expected, $barcode);
        $this->assertMatchesRegularExpression('/^\d{13}$/', $barcode);
        $this->assertStringStartsWith('2', $barcode, 'GS1 never assigns numbers starting with 2 to a manufacturer');
        $this->assertTrue($this->hasValidEan13CheckDigit($barcode));
        $this->assertSame($id, ProductVariant::idFromBarcode($barcode));
    }

    public function test_the_check_digit_matches_a_real_manufacturer_ean13(): void
    {
        // 4006381333931 is a real retail EAN-13; the test's own check agrees with it,
        // so it is a fair judge of the codes above.
        $this->assertTrue($this->hasValidEan13CheckDigit('4006381333931'));
        $this->assertFalse($this->hasValidEan13CheckDigit('4006381333932'));
    }

    public function test_ids_outside_seven_digits_are_refused_rather_than_truncated(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        ProductVariant::barcodeFor(10_000_000);
    }

    public static function barcodesToRead(): array
    {
        return [
            'current barcode'                    => ['2984200059847', 5984],
            'with spaces around it'              => [" 2984200059847\n", 5984],
            'old label TGC-'                     => ['TGC-00005984', 5984],
            'old label TGC-VAR-'                 => ['TGC-VAR-00005984', 5984],
            'wrong check digit (misread)'        => ['2984200059846', null],
            'another manufacturer EAN-13'        => ['4006381333931', null],
            'shop-generated in-store code'       => ['2000000059841', null],
            'too short'                          => ['298420005984', null],
            'unit serial'                        => ['TGC-U-00005984', null],
            'label QR'                           => ['P12 I5984', null],
            'zero id'                            => ['TGC-00000000', null],
        ];
    }

    #[DataProvider('barcodesToRead')]
    public function test_reading_a_barcode(string $barcode, ?int $expectedId): void
    {
        $this->assertSame($expectedId, ProductVariant::idFromBarcode($barcode));
    }

    public function test_a_new_variant_gets_a_digits_only_barcode(): void
    {
        $variant = app(ProductVariantService::class)->findOrCreate(ProductColor::factory()->create()->id, null);

        $this->assertSame(ProductVariant::barcodeFor($variant->id), $variant->barcode_value);
    }

    public function test_lookup_finds_the_product_by_new_and_old_printed_barcodes(): void
    {
        $user    = User::factory()->create();
        $variant = ProductVariant::factory()->create();
        ProductVariant::factory()->create(); // a neighbour the lookup must not return
        $legacy  = sprintf('TGC-%08d', $variant->id);

        foreach ([$variant->barcode_value, $legacy] as $printed) {
            $this->actingAs($user, 'sanctum')
                ->getJson("/api/v1/product-variants/barcode/{$printed}")
                ->assertOk()
                ->assertJsonPath('data.id', $variant->id)
                ->assertJsonPath('data.barcode_value', $variant->barcode_value);

            $this->actingAs($user, 'sanctum')
                ->getJson('/api/v1/product-variants?barcode=' . urlencode($printed))
                ->assertOk()
                ->assertJsonCount(1, 'data')
                ->assertJsonPath('data.0.id', $variant->id);
        }

        $misread = substr($variant->barcode_value, 0, 12) . ((int) substr($variant->barcode_value, 12) + 1) % 10;
        $this->actingAs($user, 'sanctum')
            ->getJson("/api/v1/product-variants/barcode/{$misread}")
            ->assertNotFound();
    }

    public function test_migration_rewrites_every_barcode_and_rolls_back(): void
    {
        $variants = ProductVariant::factory()->count(3)->create();
        foreach ($variants as $variant) {
            DB::table('product_variants')->where('id', $variant->id)
                ->update(['barcode_value' => sprintf('TGC-%08d', $variant->id)]);
        }
        $migration = require database_path('migrations/2026_09_17_000001_make_product_barcodes_digits_only.php');

        $migration->up();
        foreach ($variants as $variant) {
            $this->assertSame(ProductVariant::barcodeFor($variant->id), $variant->fresh()->barcode_value);
        }

        $migration->down();
        foreach ($variants as $variant) {
            $this->assertSame(sprintf('TGC-%08d', $variant->id), $variant->fresh()->barcode_value);
        }
    }

    public function test_shipment_excel_keeps_the_barcode_as_text(): void
    {
        Storage::fake('public');
        $variant  = ProductVariant::factory()->create();
        $shipment = Shipment::factory()->create();
        ShipmentItem::factory()->create([
            'shipment_id'        => $shipment->id,
            'product_variant_id' => $variant->id,
            'quantity'           => 2,
        ]);

        app(ShipmentService::class)->generateAndStoreXlsx($shipment->id);

        $sheet = IOFactory::load(Storage::disk('public')->path("shipments/xlsx/shipment_{$shipment->id}.xlsx"))
            ->getActiveSheet();
        $cell  = $sheet->getCell('D2');

        $this->assertSame('Barcode', $sheet->getCell('D1')->getValue());
        $this->assertSame($variant->barcode_value, $cell->getValue());
        $this->assertSame(DataType::TYPE_STRING, $cell->getDataType());
    }

    private function hasValidEan13CheckDigit(string $code): bool
    {
        $sum = 0;
        foreach (str_split($code) as $i => $digit) {
            $sum += (int) $digit * ($i % 2 === 0 ? 1 : 3);
        }

        return strlen($code) === 13 && ctype_digit($code) && $sum % 10 === 0;
    }
}
