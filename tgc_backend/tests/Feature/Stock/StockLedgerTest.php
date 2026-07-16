<?php

namespace Tests\Feature\Stock;

use App\Models\ProductColor;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use App\Models\User;
use App\Models\WarehouseDocument;
use App\Services\WarehouseDocumentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The ledger is stock_movements, written only by
 * WarehouseDocumentService::syncItems() and reversed by reverseMovements().
 * The invariant that makes it trustworthy: creating a document then
 * reversing it must return net stock to exactly zero, for every document
 * type. See instructions/phase-3/01-tests-and-ci.md.
 */
class StockLedgerTest extends TestCase
{
    use RefreshDatabase;

    private WarehouseDocumentService $service;
    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = app(WarehouseDocumentService::class);
        $this->user    = User::factory()->create();
    }

    public function test_in_document_then_delete_nets_to_zero(): void
    {
        $variant = ProductVariant::factory()->create();

        $doc = $this->service->create($this->documentPayload(WarehouseDocument::TYPE_IN, $variant, 10), $this->user->id);

        $this->assertSame(10, $this->netStock($variant->id));

        $this->service->delete($doc, $this->user->id);

        $this->assertSame(0, $this->netStock($variant->id));
    }

    public function test_out_document_then_delete_nets_to_zero(): void
    {
        $variant = ProductVariant::factory()->create();

        // stock must exist before it can be shipped out
        $inDoc = $this->service->create($this->documentPayload(WarehouseDocument::TYPE_IN, $variant, 20), $this->user->id);
        $this->assertSame(20, $this->netStock($variant->id));

        $outDoc = $this->service->create($this->documentPayload(WarehouseDocument::TYPE_OUT, $variant, 8), $this->user->id);
        $this->assertSame(12, $this->netStock($variant->id));

        $this->service->delete($outDoc, $this->user->id);
        $this->assertSame(20, $this->netStock($variant->id));

        $this->service->delete($inDoc, $this->user->id);
        $this->assertSame(0, $this->netStock($variant->id));
    }

    public function test_return_document_then_delete_nets_to_zero(): void
    {
        $variant = ProductVariant::factory()->create();

        $doc = $this->service->create($this->documentPayload(WarehouseDocument::TYPE_RETURN, $variant, 5), $this->user->id);
        $this->assertSame(5, $this->netStock($variant->id));

        $this->service->delete($doc, $this->user->id);
        $this->assertSame(0, $this->netStock($variant->id));
    }

    /**
     * Adjustments must be able to reduce stock (instructions/phase-3/05-signed-adjustment-documents.md).
     * Prior to that fix, every adjustment was unconditionally mapped to
     * StockMovement::TYPE_IN regardless of intent — this test pins the
     * fixed behaviour and would fail against the old unconditional mapping.
     */
    public function test_adjustment_direction_out_reduces_stock_and_reverses_cleanly(): void
    {
        $variant = ProductVariant::factory()->create();

        $inDoc = $this->service->create($this->documentPayload(WarehouseDocument::TYPE_IN, $variant, 500), $this->user->id);
        $this->assertSame(500, $this->netStock($variant->id));

        $adjustment = $this->service->create(
            $this->documentPayload(WarehouseDocument::TYPE_ADJUSTMENT, $variant, 20, ['direction' => 'out', 'notes' => 'stocktake shrinkage']),
            $this->user->id
        );
        $this->assertSame(480, $this->netStock($variant->id));

        $this->service->delete($adjustment, $this->user->id);
        $this->assertSame(500, $this->netStock($variant->id));

        $this->service->delete($inDoc, $this->user->id);
        $this->assertSame(0, $this->netStock($variant->id));
    }

    public function test_adjustment_direction_in_increases_stock_and_reverses_cleanly(): void
    {
        $variant = ProductVariant::factory()->create();

        $adjustment = $this->service->create(
            $this->documentPayload(WarehouseDocument::TYPE_ADJUSTMENT, $variant, 20, ['direction' => 'in', 'notes' => 'found extra stock']),
            $this->user->id
        );
        $this->assertSame(20, $this->netStock($variant->id));

        $this->service->delete($adjustment, $this->user->id);
        $this->assertSame(0, $this->netStock($variant->id));
    }

    public function test_adjustment_out_cannot_drive_balance_negative(): void
    {
        $this->expectException(\Illuminate\Validation\ValidationException::class);

        $variant = ProductVariant::factory()->create();

        $this->service->create($this->documentPayload(WarehouseDocument::TYPE_IN, $variant, 5), $this->user->id);

        $this->service->create(
            $this->documentPayload(WarehouseDocument::TYPE_ADJUSTMENT, $variant, 999, ['direction' => 'out']),
            $this->user->id
        );
    }

    private function documentPayload(string $type, ProductVariant $variant, int $quantity, array $extra = []): array
    {
        $productColor = ProductColor::find($variant->product_color_id);

        return array_merge([
            'type'          => $type,
            'document_date' => now()->toDateString(),
            'items'         => [[
                'product_color_id' => $productColor->id,
                'product_size_id'  => $variant->product_size_id,
                'product_edge_id'  => $variant->product_edge_id,
                'quantity'         => $quantity,
            ]],
        ], $extra);
    }

    /**
     * Mirrors the production expression used by StockController::variants()
     * and WarehouseDocumentService::getStock(). If the two ever disagree,
     * that disagreement is the bug this helper exists to surface.
     */
    private function netStock(int $variantId): int
    {
        return (int) StockMovement::where('product_variant_id', $variantId)
            ->selectRaw("COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END), 0) as net")
            ->value('net');
    }
}
