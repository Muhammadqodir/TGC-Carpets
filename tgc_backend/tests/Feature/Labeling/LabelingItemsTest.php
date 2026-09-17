<?php

namespace Tests\Feature\Labeling;

use App\Models\Client;
use App\Models\Machine;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The labeling screen prints the client's id in the small code on the right
 * edge of every label ("S_123_04_14 15.59"), so the list it prints from has to
 * carry it, and a carpet made for stock has none.
 */
class LabelingItemsTest extends TestCase
{
    use RefreshDatabase;

    public function test_items_carry_the_client_id_of_the_order_they_are_made_for(): void
    {
        $labeller = User::factory()->labelManager()->create();
        $client   = Client::factory()->create(['shop_name' => 'A MIJOZ']);
        $variant  = ProductVariant::factory()->create();
        $order    = Order::factory()->create(['client_id' => $client->id, 'user_id' => $labeller->id]);
        $line     = OrderItem::create(['order_id' => $order->id, 'product_variant_id' => $variant->id, 'quantity' => 2]);

        $forClient = $this->batchItem($variant, $line, $labeller);
        $forStock  = $this->batchItem($variant, null, $labeller);

        $items = collect($this->actingAs($labeller, 'sanctum')
            ->getJson('/api/v1/production-batches-labeling-items')
            ->assertOk()
            ->json('data'))->keyBy('id');

        $this->assertSame($client->id, $items[$forClient->id]['client_id']);
        $this->assertSame('A MIJOZ', $items[$forClient->id]['client_name']);
        $this->assertNull($items[$forStock->id]['client_id']);
    }

    private function batchItem(ProductVariant $variant, ?OrderItem $for, User $by): ProductionBatchItem
    {
        $batch = ProductionBatch::create([
            'batch_title' => 'Sintetik partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => $for ? ProductionBatch::TYPE_BY_ORDER : ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $by->id,
        ]);

        return ProductionBatchItem::create([
            'production_batch_id'  => $batch->id,
            'source_type'          => $for ? ProductionBatchItem::SOURCE_ORDER_ITEM : ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'source_order_item_id' => $for?->id,
            'product_variant_id'   => $variant->id,
            'planned_quantity'     => 2,
            'produced_quantity'    => 0,
            'defect_quantity'      => 0,
        ]);
    }
}
