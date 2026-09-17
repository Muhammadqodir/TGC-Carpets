<?php

namespace Tests\Feature\Labeling;

use App\Models\Client;
use App\Models\Machine;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use App\Models\StockMovement;
use App\Models\User;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The home-page QR scanner: scanning a carpet's label shows who printed the
 * labels of its batch line and when, the order it was made for and how much of
 * that order has shipped, where its production came from, and current stock.
 */
class ScanItemDetailsTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_scan_shows_every_print_of_the_line_with_who_and_when(): void
    {
        $shift1  = User::factory()->labelManager()->create(['name' => '1 SMENA (YORLIQ)']);
        $shift2  = User::factory()->labelManager()->create(['name' => '2 SMENA (YORLIQ)']);
        $variant = ProductVariant::factory()->create();
        $client  = Client::factory()->create(['shop_name' => 'A MIJOZ', 'phone' => '+998901234567', 'contact_name' => 'Anvar']);
        $order   = Order::factory()->create(['client_id' => $client->id, 'user_id' => $shift1->id, 'order_date' => '2026-09-01']);
        $line    = OrderItem::create(['order_id' => $order->id, 'product_variant_id' => $variant->id, 'quantity' => 3]);
        $carpets = $this->batchItem($variant, $line, $shift1, planned: 2);
        $url     = "/api/v1/production-batches/{$carpets->production_batch_id}/items/{$carpets->id}/print-label";

        Carbon::setTestNow('2026-09-17 10:15:00');
        $this->actingAs($shift1, 'sanctum')->postJson($url, ['idempotency_key' => (string) Str::uuid()])->assertOk();
        Carbon::setTestNow('2026-09-17 21:40:00');
        $this->actingAs($shift2, 'sanctum')->postJson($url, ['idempotency_key' => (string) Str::uuid()])->assertOk();
        Carbon::setTestNow();

        $shipment = Shipment::factory()->create(['client_id' => $client->id]);
        ShipmentItem::factory()->create(['shipment_id' => $shipment->id, 'order_item_id' => $line->id, 'product_variant_id' => $variant->id, 'quantity' => 1]);
        $this->stock($variant, in: 5, out: 2);

        foreach (["P{$carpets->production_batch_id} I{$carpets->id}", "PB{$carpets->production_batch_id} PBI{$carpets->id}"] as $code) {
            $data = $this->actingAs($shift1, 'sanctum')
                ->getJson('/api/v1/production-batches-scan?code=' . urlencode($code))
                ->assertOk()
                ->json('data');

            $this->assertSame(0, $data['label_prints']['before_tracking']);
            // ISO in UTC: 10:15 and 21:40 Tashkent time (+05:00). The app shows them local.
            $this->assertSame([
                ['printed_at' => '2026-09-17T05:15:00.000000Z', 'printed_by_name' => '1 SMENA (YORLIQ)'],
                ['printed_at' => '2026-09-17T16:40:00.000000Z', 'printed_by_name' => '2 SMENA (YORLIQ)'],
            ], $data['label_prints']['prints']);

            $this->assertSame('client', $data['destination']['type']);
            $this->assertSame('A MIJOZ', $data['destination']['client_name']);
            $this->assertSame('+998901234567', $data['destination']['phone']);
            $this->assertSame('Anvar', $data['destination']['contact_name']);
            $this->assertSame($order->id, $data['destination']['order_id']);
            $this->assertSame('2026-09-01', $data['destination']['order_date']);
            $this->assertSame(3, $data['destination']['ordered_quantity']);
            $this->assertSame(1, $data['destination']['shipped_quantity']);

            $this->assertSame(2, $data['item']['produced_quantity']);
            $this->assertSame(3, $data['stock_quantity']);
            $this->assertNull($data['reattribution']);
            $this->assertNotNull($data['production_batch']['created_at']);
        }
    }

    public function test_lines_labelled_before_tracking_are_counted_not_invented(): void
    {
        $user    = User::factory()->create();
        $variant = ProductVariant::factory()->create();
        $carpets = $this->batchItem($variant, null, $user, planned: 3);
        foreach ([1, 2] as $n) {
            ProductionUnit::create([
                'production_batch_item_id' => $carpets->id,
                'serial'                   => sprintf('TGC-U-%08d', $n),
                'printed_by'               => $user->id,
                'printed_at'               => '2026-07-20 00:00:00',
                'status'                   => ProductionUnit::STATUS_GOOD,
                'backfilled_at'            => '2026-07-20 00:00:00',
            ]);
        }

        $data = $this->actingAs($user, 'sanctum')
            ->getJson("/api/v1/production-batches-scan?code=P{$carpets->production_batch_id}%20I{$carpets->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame(2, $data['label_prints']['before_tracking']);
        $this->assertSame([], $data['label_prints']['prints']);
        $this->assertSame(['type' => 'warehouse'], $data['destination']);
        $this->assertSame(0, $data['stock_quantity']);
    }

    public function test_scan_names_the_client_a_shipment_took_the_carpets_from(): void
    {
        $user     = User::factory()->create();
        $variant  = ProductVariant::factory()->create();
        $original = Client::factory()->create(['shop_name' => 'B MIJOZ']);
        $receiver = Client::factory()->create(['shop_name' => 'A MIJOZ']);
        $fromLine = OrderItem::create([
            'order_id'           => Order::factory()->create(['client_id' => $original->id, 'user_id' => $user->id])->id,
            'product_variant_id' => $variant->id,
            'quantity'           => 1,
        ]);
        $toLine = OrderItem::create([
            'order_id'           => Order::factory()->create(['client_id' => $receiver->id, 'user_id' => $user->id])->id,
            'product_variant_id' => $variant->id,
            'quantity'           => 1,
        ]);
        $shipment = Shipment::factory()->create(['client_id' => $receiver->id]);
        $carpets  = $this->batchItem($variant, $toLine, $user, planned: 1);
        $carpets->update([
            'reattributed_from_order_item_id' => $fromLine->id,
            'reattributed_by_shipment_id'     => $shipment->id,
        ]);

        $data = $this->actingAs($user, 'sanctum')
            ->getJson("/api/v1/production-batches-scan?code=P{$carpets->production_batch_id}%20I{$carpets->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame('A MIJOZ', $data['destination']['client_name']);
        $this->assertSame(['from_client_name' => 'B MIJOZ', 'shipment_id' => $shipment->id], $data['reattribution']);
    }

    private function batchItem(ProductVariant $variant, ?OrderItem $for, User $by, int $planned): ProductionBatchItem
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
            'planned_quantity'     => $planned,
            'produced_quantity'    => 0,
            'defect_quantity'      => 0,
        ]);
    }

    private function stock(ProductVariant $variant, int $in, int $out): void
    {
        $user = User::factory()->create();
        foreach ([WarehouseDocument::TYPE_IN => [$in, StockMovement::TYPE_IN], WarehouseDocument::TYPE_OUT => [$out, StockMovement::TYPE_OUT]] as $docType => [$qty, $movement]) {
            $document = WarehouseDocument::create(['type' => $docType, 'user_id' => $user->id, 'document_date' => now()->toDateString()]);
            StockMovement::create([
                'product_variant_id'         => $variant->id,
                'warehouse_document_item_id' => WarehouseDocumentItem::create([
                    'warehouse_document_id' => $document->id,
                    'product_variant_id'    => $variant->id,
                    'quantity'              => $qty,
                ])->id,
                'user_id'       => $user->id,
                'movement_type' => $movement,
                'quantity'      => $qty,
                'movement_date' => now()->toDateString(),
            ]);
        }
    }
}
