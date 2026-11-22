<?php

namespace Tests\Feature\Labeling;

use App\Models\Machine;
use App\Models\ProductColor;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductVariant;
use App\Models\User;
use App\Services\ProductImageThumbnailer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * The label-print terminal shows product photos six to a page, so the list
 * gives it a small thumbnail next to the full photo.
 */
class ProductThumbnailTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    public function test_an_uploaded_photo_gets_a_small_thumbnail_on_the_labeling_list(): void
    {
        $image = $this->photo('products/big.png', 1600, 2400);
        $pc    = ProductColor::factory()->create(['image' => $image]);

        $thumb = 'products/thumbs/big.jpg';
        Storage::disk('public')->assertExists($thumb);
        [$w, $h] = getimagesizefromstring(Storage::disk('public')->get($thumb));
        $this->assertSame([ProductImageThumbnailer::SHORT_SIDE, 1080], [$w, $h]);

        $item = $this->labelingItem($pc);
        $this->assertStringEndsWith('/storage/products/big.png', $item['variant']['product_color']['image_url']);
        $this->assertStringEndsWith('/storage/products/thumbs/big.jpg', $item['variant']['product_color']['thumb_url']);
    }

    public function test_replacing_the_photo_replaces_the_thumbnail(): void
    {
        $pc = ProductColor::factory()->create(['image' => $this->photo('products/old.jpg', 900, 900)]);
        Storage::disk('public')->assertExists('products/thumbs/old.jpg');

        $pc->update(['image' => $this->photo('products/new.webp', 800, 600)]);

        Storage::disk('public')->assertMissing('products/thumbs/old.jpg');
        Storage::disk('public')->assertExists('products/thumbs/new.jpg');
    }

    public function test_a_photo_without_a_thumbnail_falls_back_to_null(): void
    {
        Storage::disk('public')->put('products/legacy.jpg', 'not really an image');
        $pc = ProductColor::factory()->create(['image' => 'products/legacy.jpg']);

        $this->assertNull($this->labelingItem($pc)['variant']['product_color']['thumb_url']);
    }

    public function test_the_backfill_command_makes_missing_thumbnails(): void
    {
        $pc = ProductColor::factory()->create();
        $pc->forceFill(['image' => $this->photo('products/early.png', 1200, 1600)])->saveQuietly();
        Storage::disk('public')->assertMissing('products/thumbs/early.jpg');

        $this->artisan('products:thumbnails')->assertSuccessful();

        Storage::disk('public')->assertExists('products/thumbs/early.jpg');
    }

    private function photo(string $path, int $w, int $h): string
    {
        $img = imagecreatetruecolor($w, $h);
        imagefill($img, 0, 0, imagecolorallocate($img, 200, 30, 30));
        ob_start();
        match (pathinfo($path, PATHINFO_EXTENSION)) {
            'png'  => imagepng($img),
            'webp' => imagewebp($img),
            default => imagejpeg($img),
        };
        Storage::disk('public')->put($path, ob_get_clean());

        return $path;
    }

    private function labelingItem(ProductColor $pc): array
    {
        $labeller = User::factory()->labelManager()->create();
        $variant  = ProductVariant::factory()->create(['product_color_id' => $pc->id]);
        $batch    = ProductionBatch::create([
            'batch_title' => 'Partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $labeller->id,
        ]);
        ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => $variant->id,
            'planned_quantity'    => 1,
            'produced_quantity'   => 0,
            'defect_quantity'     => 0,
        ]);

        return $this->actingAs($labeller, 'sanctum')
            ->getJson('/api/v1/production-batches-labeling-items')
            ->assertOk()
            ->json('data.0');
    }
}
