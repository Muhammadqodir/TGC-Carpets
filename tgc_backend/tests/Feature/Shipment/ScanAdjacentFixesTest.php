<?php

namespace Tests\Feature\Shipment;

use App\Models\Machine;
use App\Models\ProductColor;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use App\Models\User;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The two fixes that shipped alongside the scan hardening (4e49a9c): printing
 * a label must still count exactly one carpet per print now that it locks the
 * batch item first, and the stock list must not crash on a colour image.
 */
class ScanAdjacentFixesTest extends TestCase
{
    use RefreshDatabase;

    public function test_print_label_counts_each_print_once_and_replays_a_retried_one(): void
    {
        $labeller = User::factory()->create();
        $variant  = ProductVariant::factory()->create();
        $batch    = ProductionBatch::create([
            'batch_title' => 'Sintetik partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $labeller->id,
        ]);
        $item = ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => $variant->id,
            'planned_quantity'    => 2,
            'produced_quantity'   => 0,
            'defect_quantity'     => 0,
        ]);
        $url = "/api/v1/production-batches/{$batch->id}/items/{$item->id}/print-label";
        $firstKey = (string) Str::uuid();

        $first = $this->actingAs($labeller, 'sanctum')->postJson($url, ['idempotency_key' => $firstKey])->assertOk();
        $serial = $first->json('unit.serial');
        $this->assertMatchesRegularExpression('/^TGC-U-\d{8}$/', $serial);
        $this->assertSame(1, $item->fresh()->produced_quantity);

        // The same request again (a retry after a dropped response) counts nothing.
        $this->actingAs($labeller, 'sanctum')->postJson($url, ['idempotency_key' => $firstKey])->assertOk();
        $this->assertSame(1, $item->fresh()->produced_quantity);

        // A reprint of that carpet's label counts nothing either.
        $this->actingAs($labeller, 'sanctum')->postJson($url, ['serial' => $serial])->assertOk();
        $this->assertSame(1, $item->fresh()->produced_quantity);
        $this->assertSame(1, ProductionUnit::where('serial', $serial)->value('reprint_count'));

        // A second carpet does, and finishes the batch.
        $this->actingAs($labeller, 'sanctum')->postJson($url, ['idempotency_key' => (string) Str::uuid()])->assertOk();
        $this->assertSame(2, $item->fresh()->produced_quantity);
        $this->assertSame(ProductionBatch::STATUS_COMPLETED, $batch->fresh()->status);
    }

    public function test_stock_list_shows_colour_images_instead_of_crashing(): void
    {
        $user    = User::factory()->admin()->create();
        $variant = ProductVariant::factory()->create();
        ProductColor::whereKey($variant->product_color_id)->update(['image' => 'products/sintetik.jpg']);

        $document = WarehouseDocument::create([
            'type'          => WarehouseDocument::TYPE_IN,
            'user_id'       => $user->id,
            'document_date' => now()->toDateString(),
        ]);
        StockMovement::create([
            'product_variant_id'         => $variant->id,
            'warehouse_document_item_id' => WarehouseDocumentItem::create([
                'warehouse_document_id' => $document->id,
                'product_variant_id'    => $variant->id,
                'quantity'              => 3,
            ])->id,
            'user_id'       => $user->id,
            'movement_type' => StockMovement::TYPE_IN,
            'quantity'      => 3,
            'movement_date' => now()->toDateString(),
        ]);

        $row = collect($this->actingAs($user, 'sanctum')->getJson('/api/v1/stock/variants')->assertOk()->json('data'))
            ->firstWhere('id', $variant->id);

        $this->assertNotNull($row, 'the variant with stock is listed');
        $this->assertStringEndsWith('/storage/products/sintetik.jpg', $row['image_url']);
    }
}
