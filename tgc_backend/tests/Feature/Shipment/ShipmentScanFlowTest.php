<?php

namespace Tests\Feature\Shipment;

use App\Models\Client;
use App\Models\Machine;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\StockMovement;
use App\Models\User;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use App\Services\ProductVariantStockService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * The shipment QR flow end to end, on synthetic data: a worker picks a client,
 * scans carpet labels, confirms what the app asks about, and saves.
 *
 * Every scan and save here is shaped exactly like the app's (tgc_client
 * ShipmentRemoteDataSource + ShipmentFormController + AddShipmentPage._submit):
 * code and client_id in the query string AND the JSON body, `in_form` with what
 * the form already holds, rows added/incremented by the same rule, and the same
 * save payload. The business rule under test is that a worker can ship EVERY
 * scanned carpet — the client's own, one they never ordered, another client's,
 * a warehouse carpet, one never marked produced, one never booked into stock —
 * with the app asking first whenever it is not simply this client's own.
 *
 * Labels use every QR format that reached real carpets: production began
 * 2026-05-06 with `PB{batch} PBI{item}`, switched to `P{batch} I{item}` from
 * the 2026-05-14 release, and print-history reprints of old entries carry
 * `PB{batch} VAR{variant}`.
 */
class ShipmentScanFlowTest extends TestCase
{
    use RefreshDatabase;

    private User $worker;

    /** The client selected on the shipment form. */
    private Client $clientA;

    /** Somebody else, whose carpets sometimes end up on A's lorry. */
    private Client $clientB;

    /**
     * The shipment form as ShipmentFormController holds it.
     *
     * @var list<array{order_item_id: int|null, product_variant_id: int, quantity: int, scanned: bool, scanned_batch_item_ids: list<int>}>
     */
    private array $rows = [];

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');

        $this->worker  = User::factory()->warehouseManager()->create();
        $this->clientA = Client::factory()->create(['shop_name' => 'A MIJOZ']);
        $this->clientB = Client::factory()->create(['shop_name' => 'B MIJOZ']);
    }

    // ── The six kinds of carpet ───────────────────────────────────────────────

    public function test_own_ordered_carpet_goes_straight_onto_its_order_line(): void
    {
        $variant = $this->variant();
        $line    = $this->orderLine($this->clientA, $variant, 2);
        $carpets = $this->batchItem($variant, $line, planned: 2, produced: 2, received: 2);
        $this->receive($variant, 2);

        $first = $this->scanIntoForm($this->label($carpets));

        $this->assertSame('added', $first['outcome']);
        $this->assertFalse($first['asked'], 'the client\'s own carpet must not ask for confirmation');
        $this->assertSame($line->id, $first['item']['order_item_id']);
        $this->assertNull($first['item']['produced_for_client']);
        $this->assertSame(2, $first['item']['available_quantity']);
        $this->assertSame($carpets->id, $first['item']['production_batch_item_id']);

        $this->assertSame('incremented', $this->scanIntoForm($this->label($carpets))['outcome']);

        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        $this->assertSame(1, Shipment::findOrFail($shipmentId)->items()->count());
        $this->assertSame(2, $this->shippedOn($line));
        $this->assertSame(0, $this->stock($variant));
        $this->assertSame(Order::STATUS_SHIPPED, $line->order->fresh()->status);
        $this->assertSame(2, $this->producedFor($line), 'nothing to re-attribute: the carpets were A\'s already');
        $this->assertSame(1, Order::where('client_id', $this->clientA->id)->count(), 'no order invented');
    }

    public function test_carpet_the_client_never_ordered_is_added_anyway_on_a_new_order_line(): void
    {
        $variant = $this->variant();
        $carpet  = $this->batchItem($variant, null, planned: 1, produced: 1, received: 1);
        $this->receive($variant, 1);

        $scan = $this->scanIntoForm($this->label($carpet));

        // 200, not 404: prod's nginx replaced 404 bodies with its own page.
        $this->assertSame(200, $scan['status']);
        $this->assertTrue($scan['asked']);
        $this->assertSame('added', $scan['outcome']);
        $this->assertNull($scan['item']['order_item_id']);
        $this->assertSame('no_open_line', $scan['item']['reason']);
        $this->assertNull($scan['item']['produced_for_client']);
        $this->assertSame(1, $scan['item']['stock_quantity']);

        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        $invented = Order::where('created_from_shipment_id', $shipmentId)->firstOrFail();
        $this->assertSame($this->clientA->id, $invented->client_id);
        $this->assertSame(Order::STATUS_SHIPPED, $invented->status);
        $this->assertSame(1, (int) $invented->items()->where('product_variant_id', $variant->id)->sum('quantity'));
        $this->assertSame(0, $this->stock($variant));
        $this->assertNull($carpet->fresh()->source_order_item_id, 'a warehouse carpet has nobody to take it from');
    }

    public function test_another_clients_carpet_asks_first_and_takes_its_production_record_along(): void
    {
        $variant = $this->variant();
        $lineB   = $this->orderLine($this->clientB, $variant, 1);
        $carpet  = $this->batchItem($variant, $lineB, planned: 1, produced: 1, received: 1);
        $this->receive($variant, 1);

        $scan = $this->scanIntoForm($this->label($carpet));

        $this->assertTrue($scan['asked']);
        $this->assertSame('B MIJOZ', $scan['item']['produced_for_client']);
        $this->assertSame('no_open_line', $scan['item']['reason']);
        $this->assertStringContainsString('B MIJOZ', $scan['message']);

        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        $carpet->refresh();
        $newLine = OrderItem::whereHas('order', fn ($q) => $q->where('created_from_shipment_id', $shipmentId))->firstOrFail();

        $this->assertSame($newLine->id, $carpet->source_order_item_id);
        $this->assertSame($lineB->id, $carpet->reattributed_from_order_item_id);
        $this->assertSame($shipmentId, $carpet->reattributed_by_shipment_id);
        $this->assertSame(0, $this->producedFor($lineB), 'B\'s "Tayyor" drops: the factory owes them a carpet');
        $this->assertSame(1, $lineB->fresh()->quantity, 'B\'s order itself is untouched');
    }

    public function test_a_done_order_that_loses_its_carpet_goes_back_to_production_and_returns_on_cancel(): void
    {
        $variant = $this->variant();
        $lineB   = $this->orderLine($this->clientB, $variant, 1);
        $lineB->order->update(['status' => Order::STATUS_DONE]);
        $carpet  = $this->batchItem($variant, $lineB, planned: 1, produced: 1, received: 1);
        $this->receive($variant, 1);

        $this->scanIntoForm($this->label($carpet));
        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        // 'done' is invisible to the "needs production" list; B is owed a
        // replacement, so the order must be back where that list sees it.
        $this->assertSame(Order::STATUS_PENDING, $lineB->order->fresh()->status);
        $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/orders?for_production=1')
            ->assertOk()
            ->assertJsonFragment(['id' => $lineB->order_id]);

        $admin = User::factory()->admin()->create();
        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/shipments/{$shipmentId}/cancel", ['reason' => 'test'])
            ->assertOk();

        $this->assertSame(Order::STATUS_DONE, $lineB->order->fresh()->status, 'carpet is back: B is ready again');
    }

    public function test_another_clients_carpet_lands_on_this_clients_own_line_when_they_ordered_it_too(): void
    {
        $variant = $this->variant();
        $lineA   = $this->orderLine($this->clientA, $variant, 1);
        $lineB   = $this->orderLine($this->clientB, $variant, 3);
        $carpets = $this->batchItem($variant, $lineB, planned: 3, produced: 3, received: 3);
        $this->receive($variant, 3);

        $scan = $this->scanIntoForm($this->label($carpets));

        $this->assertSame(200, $scan['status']);
        $this->assertSame($lineA->id, $scan['item']['order_item_id']);
        $this->assertSame('B MIJOZ', $scan['item']['produced_for_client']);
        $this->assertTrue($scan['asked']);

        $this->saveForm()->assertCreated();

        // One of B's three carpets split off onto A's line; two stay with B.
        $this->assertSame(2, $this->producedFor($lineB));
        $this->assertSame(1, $this->producedFor($lineA));
        $this->assertSame(3, (int) ProductionBatchItem::where('production_batch_id', $carpets->production_batch_id)->sum('produced_quantity'),
            'factory-wide production never changes, only who it belongs to');
    }

    public function test_warehouse_carpet_on_the_clients_order_goes_on_without_questions(): void
    {
        $variant = $this->variant();
        $lineA   = $this->orderLine($this->clientA, $variant, 1);
        $carpet  = $this->batchItem($variant, null, planned: 1, produced: 1, received: 1);
        $this->receive($variant, 1);

        $scan = $this->scanIntoForm($this->label($carpet));

        $this->assertSame($lineA->id, $scan['item']['order_item_id']);
        $this->assertFalse($scan['asked']);

        $this->saveForm()->assertCreated();

        $this->assertSame(1, $this->shippedOn($lineA));
        $this->assertNull($carpet->fresh()->source_order_item_id);
        $this->assertSame(0, $this->stock($variant));
    }

    public function test_carpet_never_marked_produced_can_still_be_shipped(): void
    {
        // Should not happen on the floor — a carpet with a label was printed,
        // and printing counts it produced — but the worker is holding it, so
        // it must ship. Nothing was counted as produced, so there is no
        // production record to move.
        $variant = $this->variant();
        $lineB   = $this->orderLine($this->clientB, $variant, 1);
        $carpet  = $this->batchItem($variant, $lineB, planned: 1, produced: 0);

        $scan = $this->scanIntoForm($this->label($carpet));

        $this->assertSame('added', $scan['outcome']);
        $this->assertSame('B MIJOZ', $scan['item']['produced_for_client']);
        $this->assertSame(0, $scan['item']['stock_quantity']);

        $this->saveForm()->assertCreated();

        $this->assertSame(0, $this->stock($variant), 'booked in automatically, then shipped out');
        $this->assertSame(1, $this->ledger($variant, 'in'));
        $this->assertSame(1, $this->ledger($variant, 'out'));
        $this->assertSame($lineB->id, $carpet->fresh()->source_order_item_id);
        $this->assertSame(1, $carpet->fresh()->planned_quantity, 'B still gets theirs produced');
    }

    public function test_own_carpet_never_marked_produced_ships_on_its_order_line(): void
    {
        $variant = $this->variant();
        $lineA   = $this->orderLine($this->clientA, $variant, 1);
        $carpet  = $this->batchItem($variant, $lineA, planned: 1, produced: 0);

        $scan = $this->scanIntoForm($this->label($carpet));

        $this->assertSame($lineA->id, $scan['item']['order_item_id']);
        $this->assertFalse($scan['asked']);

        $this->saveForm()->assertCreated();

        $this->assertSame(1, $this->shippedOn($lineA));
        $this->assertSame(0, $this->stock($variant));
    }

    public function test_carpet_never_booked_into_the_warehouse_is_received_and_shipped_on_save(): void
    {
        $variant = $this->variant();
        $lineA   = $this->orderLine($this->clientA, $variant, 2);
        $carpets = $this->batchItem($variant, $lineA, planned: 2, produced: 2, received: 0);

        $this->assertSame(0, $this->scanIntoForm($this->label($carpets))['item']['stock_quantity']);
        $this->scanIntoForm($this->label($carpets));

        $this->saveForm()->assertCreated();

        $autoReceipt = WarehouseDocument::where('type', WarehouseDocument::TYPE_IN)
            ->where('notes', 'like', 'Yuk xati uchun avtomatik qabul%')
            ->firstOrFail();
        $this->assertSame(2, (int) $autoReceipt->items()->sum('quantity'));
        $this->assertSame(0, $this->stock($variant));
        $this->assertSame(2, $this->shippedOn($lineA));
    }

    public function test_partial_stock_is_topped_up_only_by_the_shortfall(): void
    {
        $variant = $this->variant();
        $lineA   = $this->orderLine($this->clientA, $variant, 3);
        $carpets = $this->batchItem($variant, $lineA, planned: 3, produced: 3, received: 1);
        $this->receive($variant, 1);

        foreach (range(1, 3) as $_) {
            $this->scanIntoForm($this->label($carpets));
        }
        $this->saveForm()->assertCreated();

        $this->assertSame(3, $this->ledger($variant, 'in'), '1 received earlier + 2 booked in on save');
        $this->assertSame(0, $this->stock($variant));
    }

    // ── More carpets than the order holds ─────────────────────────────────────

    public function test_scanning_past_a_full_line_moves_to_the_next_line_then_beyond_the_order(): void
    {
        $variant = $this->variant();
        $line1   = $this->orderLine($this->clientA, $variant, 1);
        $line2   = $this->orderLine($this->clientA, $variant, 1);
        $carpets = $this->batchItem($variant, $line1, planned: 4, produced: 4, received: 4);
        $this->receive($variant, 4);
        $label = $this->label($carpets);

        $scans = array_map(fn () => $this->scanIntoForm($label), range(1, 4));

        $this->assertSame([$line1->id, $line2->id, null, null], array_map(fn ($s) => $s['item']['order_item_id'], $scans));
        $this->assertSame(['added', 'added', 'added', 'incremented'], array_column($scans, 'outcome'));
        $this->assertSame('open_lines_full', $scans[2]['item']['reason']);
        $this->assertFalse($scans[1]['asked'], 'the next open line of this client is still their own order');
        $this->assertTrue($scans[2]['asked'], 'beyond the order must be confirmed');

        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        $this->assertSame(1, $this->shippedOn($line1));
        $this->assertSame(1, $this->shippedOn($line2));
        $invented = Order::where('created_from_shipment_id', $shipmentId)->firstOrFail();
        $this->assertSame(2, (int) $invented->items()->sum('quantity'));
        $this->assertSame(0, $this->stock($variant));
    }

    public function test_an_app_that_does_not_send_in_form_resolves_exactly_as_before(): void
    {
        $variant = $this->variant();
        $line1   = $this->orderLine($this->clientA, $variant, 1);
        $this->orderLine($this->clientA, $variant, 1);
        $carpets = $this->batchItem($variant, $line1, planned: 2, produced: 2, received: 2);

        // Builds 1.3.2/1.3.3: no in_form, so the same line comes back every time.
        foreach (range(1, 2) as $_) {
            $this->actingAs($this->worker, 'sanctum')
                ->postJson('/api/v1/shipment-import/scan', ['code' => $this->label($carpets), 'client_id' => $this->clientA->id])
                ->assertOk()
                ->assertJsonPath('data.order_item_id', $line1->id);
        }
    }

    // ── A whole lorry, then cancelling it ─────────────────────────────────────

    public function test_one_lorry_with_every_kind_of_carpet_saves_and_cancelling_restores_everything(): void
    {
        $own          = $this->variant();
        $ownLine      = $this->orderLine($this->clientA, $own, 1);
        $ownCarpet    = $this->batchItem($own, $ownLine, 1, 1, 1);
        $this->receive($own, 1);

        $stockOnly    = $this->variant();
        $stockCarpet  = $this->batchItem($stockOnly, null, 1, 1, 1);
        $this->receive($stockOnly, 1);

        $theirs       = $this->variant();
        $theirLine    = $this->orderLine($this->clientB, $theirs, 1);
        $theirCarpet  = $this->batchItem($theirs, $theirLine, 1, 1, 1);
        $this->receive($theirs, 1);

        $notProduced  = $this->variant();
        $npLine       = $this->orderLine($this->clientB, $notProduced, 1);
        $npCarpet     = $this->batchItem($notProduced, $npLine, 1, 0);

        $noStock      = $this->variant();
        $noStockLine  = $this->orderLine($this->clientA, $noStock, 1);
        $noStockItem  = $this->batchItem($noStock, $noStockLine, 1, 1, 0);

        $labels = [
            $this->label($ownCarpet),
            "PB{{$stockCarpet->production_batch_id}} PBI{{$stockCarpet->id}}",   // May 2026 label
            $this->unitSerial($theirCarpet),
            $this->label($npCarpet),
            "PB{{$noStockItem->production_batch_id}} VAR{{$noStock->id}}",       // history reprint
        ];

        foreach ($labels as $label) {
            $scan = $this->scanIntoForm($label);
            $this->assertSame('added', $scan['outcome'], "label {$label}: " . json_encode($scan));
        }
        $this->assertCount(5, $this->rows);

        $shipmentId = $this->saveForm()->assertCreated()->json('data.id');

        foreach ([$own, $stockOnly, $theirs, $notProduced, $noStock] as $variant) {
            $this->assertSame(0, $this->stock($variant), "variant {$variant->id} left the warehouse");
        }
        $this->assertSame(0, $this->producedFor($theirLine));
        $this->assertSame(1, Order::where('created_from_shipment_id', $shipmentId)->count(), 'one invented order for the whole lorry');

        $admin = User::factory()->admin()->create();
        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/shipments/{$shipmentId}/cancel", ['reason' => 'test'])
            ->assertOk();

        $this->assertNotNull(Shipment::find($shipmentId)->canceled_at);
        $this->assertSame(1, $this->stock($own));
        $this->assertSame(1, $this->stock($stockOnly));
        $this->assertSame(1, $this->stock($theirs));
        $this->assertSame(1, $this->stock($notProduced), 'the auto-received carpet came back too');
        $this->assertSame(1, $this->stock($noStock));
        $this->assertSame($theirLine->id, $theirCarpet->fresh()->source_order_item_id, 'B gets their carpet back');
        $this->assertSame(1, $this->producedFor($theirLine));
        $this->assertSame(Order::STATUS_CANCELED, Order::where('created_from_shipment_id', $shipmentId)->value('status'));
        $this->assertSame(0, $this->shippedOn($ownLine));
    }

    // ── Labels ────────────────────────────────────────────────────────────────

    /** Every QR text a real label carries, with the misreads a camera adds. */
    public static function printedLabels(): array
    {
        return [
            'P{batch} I{item} — printed since 2026-05-14'       => ['P%b I%i', true],
            'PB{batch} PBI{item} — printed 2026-05-06..14'       => ['PB{%b} PBI{%i}', true],
            'PB{batch} VAR{variant} — print-history reprint'     => ['PB{%b} VAR{%v}', false],
            'TGC-U serial — minted per print, not yet on labels' => ['%s', true],
            'lower case'                                         => ['p%b i%i', true],
            'two spaces'                                         => ['P%b  I%i', true],
            'tab between'                                        => ["P%b\tI%i", true],
            'trailing newline'                                   => ["P%b I%i\n", true],
            'surrounding spaces and CRLF'                        => ["  P%b I%i\r\n", true],
            'braces on the short format'                         => ['P{%b} I{%i}', true],
        ];
    }

    #[DataProvider('printedLabels')]
    public function test_every_printed_label_format_resolves_to_its_carpet(string $pattern, bool $namesTheCarpet): void
    {
        $variant = $this->variant();
        $line    = $this->orderLine($this->clientA, $variant, 5);
        $carpets = $this->batchItem($variant, $line, planned: 5, produced: 5, received: 5);
        $code    = strtr($pattern, [
            '%b' => $carpets->production_batch_id,
            '%i' => $carpets->id,
            '%v' => $variant->id,
            '%s' => $this->unitSerial($carpets),
        ]);

        $response = $this->scan($code)->assertOk();

        $this->assertSame($variant->id, $response->json('data.variant_id'));
        $this->assertSame($line->id, $response->json('data.order_item_id'));
        $this->assertSame($namesTheCarpet ? $carpets->id : null, $response->json('data.production_batch_item_id'));
    }

    public static function unreadableCodes(): array
    {
        return [
            'random text'                       => ['salom dunyo'],
            'batch and item do not belong'      => ['P%other I%i'],
            'item that does not exist'          => ['P%b I99999999'],
            'unit serial that does not exist'   => ['TGC-U-99999999'],
            'variant that does not exist'       => ['PB{%b} VAR{99999999}'],
            'April 2026 dev format batch/item'  => ['%b/%i'],
            'the old product barcode text'      => ['TGC-VAR-00000042'],
            'the digits-only product barcode'   => ['2984200000429'],
            'a URL'                             => ['https://erp.tgc-carpets.uz/p/1'],
        ];
    }

    #[DataProvider('unreadableCodes')]
    public function test_codes_that_name_no_carpet_say_so(string $pattern): void
    {
        $variant = $this->variant();
        $carpets = $this->batchItem($variant, null, 1, 1);
        $other   = $this->batchItem($variant, null, 1, 1);
        $code    = strtr($pattern, [
            '%other' => $other->production_batch_id,
            '%b'     => $carpets->production_batch_id,
            '%i'     => $carpets->id,
        ]);

        // 422 under `label`: a 404 body never got past prod's nginx, and a
        // `code` error would trigger the app's silent lost-input retry.
        $this->scan($code)
            ->assertStatus(422)
            ->assertJsonPath('message', 'Mahsulot topilmadi.')
            ->assertJsonValidationErrors(['label'])
            ->assertJsonMissingValidationErrors(['code', 'client_id']);
    }

    // ── Getting the request there ─────────────────────────────────────────────

    public function test_a_scan_whose_body_is_lost_still_resolves_from_the_query_string(): void
    {
        [$carpets] = $this->ownCarpet();

        $this->actingAs($this->worker, 'sanctum')
            ->call('POST', '/api/v1/shipment-import/scan?' . http_build_query([
                'code' => $this->label($carpets), 'client_id' => $this->clientA->id,
            ]), [], [], [], ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], '')
            ->assertOk()
            ->assertJsonPath('data.production_batch_item_id', $carpets->id);
    }

    public function test_a_body_laravel_cannot_decode_is_recovered(): void
    {
        [$carpets] = $this->ownCarpet();
        $code = $this->label($carpets);

        foreach ([
            'invalid UTF-8'        => "{\"code\":\"{$code}\",\"client_id\":{$this->clientA->id},\"x\":\"\xC3\"}",
            'form body as JSON'    => http_build_query(['code' => $code, 'client_id' => $this->clientA->id]),
        ] as $case => $body) {
            $this->actingAs($this->worker, 'sanctum')
                ->call('POST', '/api/v1/shipment-import/scan', [], [], [], ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], $body)
                ->assertOk()
                ->assertJsonPath('data.production_batch_item_id', $carpets->id, $case);
        }
    }

    public function test_a_scan_with_nothing_in_it_answers_in_uzbek(): void
    {
        $this->actingAs($this->worker, 'sanctum')
            ->call('POST', '/api/v1/shipment-import/scan', [], [], [], ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], '')
            ->assertStatus(422)
            ->assertJsonPath('message', "So'rov serverga to'liq yetib kelmadi. Qayta skanerlang.")
            ->assertJsonStructure(['errors' => ['code', 'client_id']]);
    }

    // ── Fixtures ──────────────────────────────────────────────────────────────

    /** @return array{0: ProductionBatchItem, 1: OrderItem} */
    private function ownCarpet(): array
    {
        $variant = $this->variant();
        $line    = $this->orderLine($this->clientA, $variant, 1);

        return [$this->batchItem($variant, $line, 1, 1, 1), $line];
    }

    private function variant(): ProductVariant
    {
        return ProductVariant::factory()->create();
    }

    private function orderLine(Client $client, ProductVariant $variant, int $quantity): OrderItem
    {
        $order = Order::factory()->create([
            'client_id' => $client->id,
            'user_id'   => $this->worker->id,
            'status'    => Order::STATUS_ON_PRODUCTION,
        ]);

        return OrderItem::create([
            'order_id'           => $order->id,
            'product_variant_id' => $variant->id,
            'quantity'           => $quantity,
        ]);
    }

    /** One batch line; [$for] null = produced for stock, not for any order. */
    private function batchItem(
        ProductVariant $variant,
        ?OrderItem $for,
        int $planned,
        int $produced,
        int $received = 0,
    ): ProductionBatchItem {
        $batch = ProductionBatch::create([
            'batch_title' => 'Sintetik partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => $for ? ProductionBatch::TYPE_BY_ORDER : ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $this->worker->id,
        ]);

        return ProductionBatchItem::create([
            'production_batch_id'         => $batch->id,
            'source_type'                 => $for ? ProductionBatchItem::SOURCE_ORDER_ITEM : ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'source_order_item_id'        => $for?->id,
            'product_variant_id'          => $variant->id,
            'planned_quantity'            => $planned,
            'produced_quantity'           => $produced,
            'defect_quantity'             => 0,
            'warehouse_received_quantity' => $received,
        ]);
    }

    /** A normal warehouse receipt, written the way WarehouseDocumentService writes one. */
    private function receive(ProductVariant $variant, int $quantity): void
    {
        $document = WarehouseDocument::create([
            'type'          => WarehouseDocument::TYPE_IN,
            'user_id'       => $this->worker->id,
            'document_date' => now()->toDateString(),
        ]);
        $item = WarehouseDocumentItem::create([
            'warehouse_document_id' => $document->id,
            'product_variant_id'    => $variant->id,
            'quantity'              => $quantity,
        ]);
        StockMovement::create([
            'product_variant_id'         => $variant->id,
            'warehouse_document_item_id' => $item->id,
            'user_id'                    => $this->worker->id,
            'movement_type'              => StockMovement::TYPE_IN,
            'quantity'                   => $quantity,
            'movement_date'              => now()->toDateString(),
        ]);
        app(ProductVariantStockService::class)->applyDelta($variant->id, StockMovement::TYPE_IN, $quantity);
    }

    /** The QR the label printer puts on a carpet today (label_qr_format.dart). */
    private function label(ProductionBatchItem $carpets): string
    {
        return "P{$carpets->production_batch_id} I{$carpets->id}";
    }

    private function unitSerial(ProductionBatchItem $carpets): string
    {
        $unit = ProductionUnit::create([
            'production_batch_item_id' => $carpets->id,
            'serial'                   => 'PENDING',
            'printed_by'               => $this->worker->id,
            'printed_at'               => now(),
            'status'                   => ProductionUnit::STATUS_GOOD,
        ]);
        $unit->update(['serial' => sprintf('TGC-U-%08d', $unit->id)]);

        return $unit->serial;
    }

    // ── The app, reduced to what reaches the server ───────────────────────────

    /** ShipmentRemoteDataSource._scanOnce: query string + JSON body + in_form. */
    private function scan(string $code, ?Client $client = null, array $inForm = []): TestResponse
    {
        $client ??= $this->clientA;
        $body = ['code' => $code, 'client_id' => $client->id];
        if ($inForm !== []) {
            $body['in_form'] = (object) array_combine(array_map('strval', array_keys($inForm)), $inForm);
        }

        return $this->actingAs($this->worker, 'sanctum')->postJson(
            '/api/v1/shipment-import/scan?' . http_build_query(['code' => $code, 'client_id' => $client->id]),
            $body,
        );
    }

    /**
     * One scan through ShipmentQrScannerPage: resolve, ask when it is not
     * simply this client's own carpet (the worker always says yes here — the
     * rule is that every scanned carpet can ship), then addOrIncrementItem.
     *
     * @return array{status: int, asked: bool, outcome: string, item: array<string, mixed>|null, message: string|null}
     */
    private function scanIntoForm(string $code): array
    {
        $response = $this->scan($code, $this->clientA, $this->inForm());
        $item = match (true) {
            // Exactly what the released app reads: a 200 with the item under
            // `data`, its null order_item_id meaning "ask, then add anyway".
            $response->status() === 200 => $response->json('data'),
            default                                                       => null,
        };

        if ($item === null) {
            return ['status' => $response->status(), 'asked' => false, 'outcome' => 'error', 'item' => null, 'message' => $response->json('message')];
        }

        return [
            'status'  => $response->status(),
            'asked'   => $item['order_item_id'] === null || $item['produced_for_client'] !== null,
            'outcome' => $this->addOrIncrement($item),
            'item'    => $item,
            'message' => $response->json('message'),
        ];
    }

    /** ShipmentFormController.addOrIncrementItem. */
    private function addOrIncrement(array $item): string
    {
        foreach ($this->rows as $index => $row) {
            $sameRow = $item['order_item_id'] !== null
                ? $row['order_item_id'] === $item['order_item_id']
                : $row['order_item_id'] === null && $row['product_variant_id'] === $item['variant_id'];
            if (! $sameRow) {
                continue;
            }

            if ($item['order_item_id'] !== null && $row['quantity'] >= $item['available_quantity']) {
                return 'limitReached';
            }
            $this->rows[$index]['quantity']++;
            if ($item['production_batch_item_id'] !== null) {
                $this->rows[$index]['scanned_batch_item_ids'][] = $item['production_batch_item_id'];
            }

            return 'incremented';
        }

        $this->rows[] = [
            'order_item_id'          => $item['order_item_id'],
            'product_variant_id'     => $item['variant_id'],
            'quantity'               => 1,
            'scanned'                => true,
            'scanned_batch_item_ids' => $item['production_batch_item_id'] !== null ? [$item['production_batch_item_id']] : [],
        ];

        return 'added';
    }

    /** ShipmentFormController.quantitiesByOrderItem. */
    private function inForm(): array
    {
        $quantities = [];
        foreach ($this->rows as $row) {
            if ($row['order_item_id'] !== null) {
                $quantities[$row['order_item_id']] = ($quantities[$row['order_item_id']] ?? 0) + $row['quantity'];
            }
        }

        return $quantities;
    }

    /** AddShipmentPage._submit. */
    private function saveForm(): TestResponse
    {
        $items = array_map(fn (array $row) => array_merge(
            [
                'order_item_id'      => $row['order_item_id'],
                'product_variant_id' => $row['product_variant_id'],
                'quantity'           => $row['quantity'],
            ],
            $row['scanned'] ? ['scanned' => true] : [],
            $row['scanned'] && $row['scanned_batch_item_ids'] !== [] ? ['scanned_batch_item_ids' => $row['scanned_batch_item_ids']] : [],
        ), $this->rows);

        return $this->actingAs($this->worker, 'sanctum')->postJson('/api/v1/shipments', [
            'client_id'         => $this->clientA->id,
            'shipment_datetime' => now()->format('Y-m-d\TH:i:s.v'),
            'items'             => $items,
        ]);
    }

    // ── Reading the result ────────────────────────────────────────────────────

    private function stock(ProductVariant $variant): int
    {
        return $this->ledger($variant, 'in') - $this->ledger($variant, 'out');
    }

    private function ledger(ProductVariant $variant, string $type): int
    {
        return (int) StockMovement::where('product_variant_id', $variant->id)->where('movement_type', $type)->sum('quantity');
    }

    /** The "Tayyor" count of an order line. */
    private function producedFor(OrderItem $line): int
    {
        return (int) ProductionBatchItem::where('source_order_item_id', $line->id)->sum('produced_quantity');
    }

    private function shippedOn(OrderItem $line): int
    {
        return (int) $line->shipmentItems()
            ->whereHas('shipment', fn ($q) => $q->whereNull('canceled_at'))
            ->sum('quantity');
    }
}
