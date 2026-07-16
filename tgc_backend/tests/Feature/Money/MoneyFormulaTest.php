<?php

namespace Tests\Feature\Money;

use App\Models\Client;
use App\Models\Color;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\ProductColor;
use App\Models\ProductQuality;
use App\Models\ProductSize;
use App\Models\ProductType;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use App\Models\User;
use App\Services\ClientDebitService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * There is exactly one money formula: ShipmentItem::lineTotal(). These tests
 * pin its rounding boundaries and, most importantly, prove that the number
 * it produces per line is exactly what ClientDebitService sums into the
 * client's ledger — a one-cent divergence per line across a large shipment
 * is real, permanent drift. See instructions/phase-3/01-tests-and-ci.md.
 */
class MoneyFormulaTest extends TestCase
{
    use RefreshDatabase;

    public function test_m2_half_cent_rounds_up(): void
    {
        // sqm = 100 * 125 * 1 / 10000 = 1.25; gross = 0.02 * 1.25 = 0.025 exactly.
        $item = $this->makeShipmentItem(price: '0.02', quantity: 1, unit: 'm2', length: 100, width: 125);

        $this->assertSame('0.03', $item->lineTotal());
    }

    public function test_m2_odd_size_matches_hand_calculation(): void
    {
        // A 175x265 carpet: sqm = 175 * 265 / 10000 = 4.6375; price 1.00 -> 4.6375, rounds to 4.64.
        $item = $this->makeShipmentItem(price: '1.00', quantity: 1, unit: 'm2', length: 175, width: 265);

        $this->assertSame('4.64', $item->lineTotal());
    }

    public function test_piece_unit_ignores_size_entirely(): void
    {
        $item = $this->makeShipmentItem(price: '12.50', quantity: 4, unit: 'piece');

        $this->assertSame('50.00', $item->lineTotal());
    }

    public function test_m2_and_piece_diverge_for_the_same_numbers(): void
    {
        // Same price and quantity, only unit differs: m2 must NOT equal piece
        // once a size is involved, because the m2 formula multiplies by area.
        $m2Item    = $this->makeShipmentItem(price: '10.00', quantity: 2, unit: 'm2', length: 100, width: 150);
        $pieceItem = $this->makeShipmentItem(price: '10.00', quantity: 2, unit: 'piece');

        $this->assertSame('30.00', $m2Item->lineTotal());   // 100*150*2/10000=3 sqm * 10.00
        $this->assertSame('20.00', $pieceItem->lineTotal()); // 10.00 * 2
    }

    public function test_zero_quantity_is_zero(): void
    {
        $item = $this->makeShipmentItem(price: '99.99', quantity: 0, unit: 'piece');

        $this->assertSame('0.00', $item->lineTotal());
    }

    public function test_zero_price_is_zero(): void
    {
        $item = $this->makeShipmentItem(price: '0.00', quantity: 100, unit: 'm2', length: 200, width: 300);

        $this->assertSame('0.00', $item->lineTotal());
    }

    /**
     * No discount (the default for every row that predates
     * instructions/phase-3/04-currency-vat-discount.md, and for every row
     * created without one) must produce EXACTLY the pre-discount figure —
     * this is the byte-identical-for-existing-data guarantee.
     */
    public function test_no_discount_matches_old_formula_exactly(): void
    {
        $item = $this->makeShipmentItem(price: '10.00', quantity: 3, unit: 'piece');

        $this->assertSame('0.00', $item->discountAmount());
        $this->assertSame($item->grossAmount(), $item->lineTotal());
        $this->assertSame('30.00', $item->lineTotal());
    }

    public function test_percent_discount_rounds_once_then_subtracts(): void
    {
        // gross = 10.00 * 3 = 30.00; 15% of 30.00 = 4.50; net = 25.50.
        $item = $this->makeShipmentItem(price: '10.00', quantity: 3, unit: 'piece');
        $item->discount_type  = 'percent';
        $item->discount_value = '15';

        $this->assertSame('30.00', $item->grossAmount());
        $this->assertSame('4.50', $item->discountAmount());
        $this->assertSame('25.50', $item->lineTotal());
    }

    public function test_flat_discount_never_exceeds_gross(): void
    {
        $item = $this->makeShipmentItem(price: '10.00', quantity: 1, unit: 'piece');
        $item->discount_type  = 'amount';
        $item->discount_value = '999.00'; // absurdly larger than the 10.00 gross

        $this->assertSame('10.00', $item->discountAmount());
        $this->assertSame('0.00', $item->lineTotal());
    }

    /**
     * The test that matters: the invoice figure (sum of ShipmentItem::lineTotal())
     * must equal what ClientDebitService charges the client, to the cent, on a
     * shipment with an odd m2 size that forces rounding on every line.
     */
    public function test_invoice_total_matches_ledger_total_on_odd_sized_shipment(): void
    {
        $client = Client::factory()->create();
        $user   = User::factory()->create();
        $order  = Order::factory()->create(['client_id' => $client->id, 'user_id' => $user->id]);

        $type    = ProductType::factory()->create();
        $quality = ProductQuality::factory()->create();
        $product = Product::factory()->create([
            'unit'                => 'm2',
            'product_type_id'     => $type->id,
            'product_quality_id'  => $quality->id,
        ]);
        $productColor = ProductColor::factory()->create(['product_id' => $product->id, 'color_id' => Color::factory()]);
        $size          = ProductSize::factory()->create(['length' => 175, 'width' => 265, 'product_type_id' => $type->id]);

        $shipment = Shipment::factory()->create(['client_id' => $client->id, 'user_id' => $user->id, 'order_id' => $order->id]);

        $expectedTotal = '0.00';
        foreach ([1.00, 3.33, 7.77, 12.01, 0.99] as $price) {
            $variant   = ProductVariant::factory()->create(['product_color_id' => $productColor->id, 'product_size_id' => $size->id]);
            $orderItem = OrderItem::factory()->create(['order_id' => $order->id, 'product_variant_id' => $variant->id, 'quantity' => 5]);

            $shipmentItem = ShipmentItem::factory()->create([
                'shipment_id'        => $shipment->id,
                'order_item_id'      => $orderItem->id,
                'product_variant_id' => $variant->id,
                'quantity'           => 5,
                'price'              => $price,
            ]);

            $expectedTotal = bcadd($expectedTotal, $shipmentItem->fresh(['variant.productColor.product', 'variant.productSize'])->lineTotal(), 2);
        }

        $ledger = app(ClientDebitService::class)->getLedger($client);

        $this->assertSame($expectedTotal, $ledger['summary']['total_debit']);
    }

    private function makeShipmentItem(string $price, int $quantity, string $unit, ?int $length = null, ?int $width = null): ShipmentItem
    {
        $type    = ProductType::factory()->create();
        $quality = ProductQuality::factory()->create();
        $product = Product::factory()->create([
            'unit'                => $unit,
            'product_type_id'     => $type->id,
            'product_quality_id'  => $quality->id,
        ]);
        $productColor = ProductColor::factory()->create(['product_id' => $product->id, 'color_id' => Color::factory()]);
        $productColor->setRelation('product', $product);

        $size = null;
        if ($length !== null && $width !== null) {
            $size = ProductSize::factory()->create(['length' => $length, 'width' => $width, 'product_type_id' => $type->id]);
        }

        $variant = ProductVariant::factory()->create([
            'product_color_id' => $productColor->id,
            'product_size_id'  => $size?->id,
        ]);
        $variant->setRelation('productColor', $productColor);
        $variant->setRelation('productSize', $size);

        $item = new ShipmentItem(['price' => $price, 'quantity' => $quantity]);
        $item->setRelation('variant', $variant);

        return $item;
    }
}
