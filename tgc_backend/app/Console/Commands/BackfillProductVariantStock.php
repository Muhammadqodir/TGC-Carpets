<?php

namespace App\Console\Commands;

use App\Models\ProductVariant;
use App\Models\StockMovement;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Compute each variant's balance from stock_movements and upsert it into
 * product_variant_stock. Idempotent by construction — it recomputes from
 * the ledger and overwrites, so running it twice is a no-op. See
 * instructions/phase-2/07-product-variant-stock-balance.md.
 *
 * IMPORTANT: run this while writes are paused (maintenance window /
 * php artisan down), or it races the dual-write — a movement landing
 * between this command's SUM and its upsert gets counted once here and
 * again by the live dual-write. If you cannot pause writes, run this and
 * then immediately run `stock:reconcile --fix` to correct anything that
 * raced; that is safe only because nothing reads this table yet.
 */
class BackfillProductVariantStock extends Command
{
    protected $signature = 'stock:backfill-balances
                            {--chunk=500 : rows per batch}
                            {--dry-run   : report only, write nothing}';

    protected $description = 'Recompute product_variant_stock.quantity from SUM(stock_movements) for every variant (idempotent).';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $chunk  = (int) $this->option('chunk');
        $now    = now();
        $written = 0;

        ProductVariant::query()
            ->orderBy('id')
            ->chunkById($chunk, function ($variants) use (&$written, $dryRun, $now): void {
                foreach ($variants as $variant) {
                    $qty = (int) DB::table('stock_movements')
                        ->where('product_variant_id', $variant->id)
                        ->selectRaw(
                            'COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE -quantity END), 0) AS q',
                            [StockMovement::TYPE_IN],
                        )
                        ->value('q');

                    if (! $dryRun) {
                        DB::table('product_variant_stock')->upsert(
                            [[
                                'product_variant_id' => $variant->id,
                                'quantity'            => $qty,
                                'created_at'          => $now,
                                'updated_at'          => $now,
                            ]],
                            ['product_variant_id'],
                            ['quantity', 'updated_at'],   // recompute on re-run: idempotent
                        );
                    }

                    $written++;
                }

                $this->info("… {$written} balances prepared");
            });

        $this->info(($dryRun ? '[dry-run] would write ' : 'wrote ') . "{$written} balances.");

        return self::SUCCESS;
    }
}
