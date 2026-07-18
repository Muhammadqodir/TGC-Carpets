<?php

namespace App\Services;

use App\Models\StockMovement;
use Illuminate\Support\Facades\DB;

/**
 * The product_variant_stock balance row — see
 * instructions/phase-2/07-product-variant-stock-balance.md.
 *
 * stock_movements stays the source of truth; this is a cache written in the
 * SAME transaction as every movement, so it can be SELECT ... FOR UPDATE'd
 * (a live SUM has no row to lock, which is why stock can currently go
 * negative under concurrent OUT documents — see the instruction file).
 *
 * Every single writer of stock_movements MUST call applyDelta() in the same
 * transaction as its StockMovement::create() call, or the balance silently
 * drifts from the ledger. Current writers, verified by grep:
 *   - WarehouseDocumentService::syncItems()      (in/out/return/adjustment)
 *   - WarehouseDocumentService::reverseMovements() (document update/delete)
 *   - ShipmentService::create()                   (out)
 *
 * Nothing reads this table yet in this deploy — see the instruction file's
 * expand → dual-write → backfill → verify → switch-reads → contract
 * sequence. getStock() in WarehouseDocumentService/ShipmentService and
 * StockController still read the live SUM until a week of clean
 * `stock:reconcile` runs proves no writer was missed.
 */
class ProductVariantStockService
{
    public function applyDelta(int $variantId, string $movementType, int $quantity): void
    {
        $delta = $movementType === StockMovement::TYPE_IN ? $quantity : -$quantity;

        // Create-or-lock, then update. upsert() handles the first-ever
        // movement for a variant; the update below applies the delta
        // atomically under the database's own row lock (quantity = quantity
        // + delta in SQL, never a PHP read-modify-write).
        //
        // The third argument must be a NON-empty column list: Laravel's
        // upsert() treats an empty array as "just INSERT, no conflict
        // clause at all" (Builder::upsert()), not "do nothing on conflict".
        // With `[]` this degraded into a plain INSERT that only ever
        // succeeded for a variant's first-ever movement, then threw a
        // duplicate-key error on the primary key for every one after.
        // Setting the PK to itself is a genuine no-op on conflict.
        DB::table('product_variant_stock')->upsert(
            [[
                'product_variant_id' => $variantId,
                'quantity'           => 0,
                'created_at'         => now(),
                'updated_at'         => now(),
            ]],
            ['product_variant_id'],
            ['product_variant_id'],
        );

        DB::table('product_variant_stock')
            ->where('product_variant_id', $variantId)
            ->update([
                'quantity'   => DB::raw("quantity + ({$delta})"),
                'updated_at' => now(),
            ]);
    }
}
