<?php

namespace App\Console\Commands;

use App\Models\ProductVariant;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Phase-1 step 05, stage 1. Two SKU generators have disagreed on axis order
 * and edge-suffix format since April (see
 * instructions/phase-1/05-variant-unique-constraint.md "The two SKU
 * generators disagree on axis order"), so sku_code — the only thing
 * actually guarding variant identity today — sometimes fails to catch a
 * duplicate.
 *
 * This command recomputes ProductVariant::generateSku() for every row and
 * reports what would change and, more importantly, which rows would
 * *collide* — i.e. generate the identical new SKU as another row. A
 * collision is the sharpest possible evidence of a duplicate: two rows that
 * were only distinct because their SKU format happened to differ.
 *
 * Dry-run by default. --force only rewrites sku_code for rows whose new
 * value does not collide with anything; colliding groups are left
 * completely untouched and printed as "still needs a merge" — that list is
 * stage 2/3's input, not something this command resolves.
 */
class ReconcileVariantSkus extends Command
{
    protected $signature = 'variants:reconcile-skus {--force : Actually write non-colliding rows. Without this, report only.}';

    protected $description = 'Recompute sku_code from ProductVariant::generateSku() for every variant and report collisions (= duplicates).';

    public function handle(): int
    {
        $force = (bool) $this->option('force');

        $variants = ProductVariant::with([
            'productColor.product',
            'productColor.color',
            'productSize',
            'productEdge',
        ])->orderBy('id')->get();

        $computed = [];   // variantId => new sku
        $byNewSku = [];   // new sku => [variantId, ...]

        foreach ($variants as $variant) {
            $pc = $variant->productColor;
            if (! $pc || ! $pc->product || ! $pc->color) {
                $this->warn("Variant {$variant->id}: missing product_color/product/color relation — skipped.");
                continue;
            }

            $newSku = ProductVariant::generateSku(
                $pc->product->name,
                $pc->product->product_quality_id,
                $pc->product->product_type_id,
                $pc->color->name,
                $variant->productSize,
                $variant->productEdge?->code,
            );

            $computed[$variant->id] = $newSku;
            $byNewSku[$newSku][] = $variant->id;
        }

        $collisions = array_filter($byNewSku, fn ($ids) => count($ids) > 1);
        $changed    = 0;
        $unchanged  = 0;

        $this->info('── Rows whose sku_code would change ──');
        $rows = [];
        foreach ($variants as $variant) {
            $newSku = $computed[$variant->id] ?? null;
            if ($newSku === null) {
                continue;
            }
            if ($newSku !== $variant->sku_code) {
                $rows[] = [$variant->id, $variant->sku_code, $newSku, count($byNewSku[$newSku]) > 1 ? 'COLLIDES' : 'ok'];
            }
        }

        if ($rows === []) {
            $this->line('  (none — every variant already matches generateSku())');
        } else {
            $this->table(['id', 'current sku', 'new sku', 'status'], $rows);
        }

        $this->newLine();
        $this->info('── Collisions: two or more variants that would generate the SAME new sku_code ──');
        $this->comment('These are your duplicate list — do not suppress them. Input to variants:find-duplicates / variants:merge-duplicates.');

        if ($collisions === []) {
            $this->line('  (none)');
        } else {
            foreach ($collisions as $sku => $ids) {
                $this->line("  {$sku} => variant ids: " . implode(', ', $ids));
            }
        }

        if (! $force) {
            $this->newLine();
            $this->comment('Dry run only. Re-run with --force to write sku_code for non-colliding rows.');

            return self::SUCCESS;
        }

        $this->newLine();
        $this->warn('--force: writing sku_code for every non-colliding row that changed. Colliding groups are left untouched.');

        DB::transaction(function () use ($variants, $computed, $collisions, &$changed, &$unchanged): void {
            foreach ($variants as $variant) {
                $newSku = $computed[$variant->id] ?? null;
                if ($newSku === null || isset($collisions[$newSku])) {
                    continue;   // collision: leave alone, this is stage 3's job
                }

                if ($newSku !== $variant->sku_code) {
                    $variant->update(['sku_code' => $newSku]);
                    $changed++;
                } else {
                    $unchanged++;
                }
            }
        });

        $this->info("Done. Rewrote {$changed} rows. " . count($collisions) . ' collision group(s) left untouched.');

        return self::SUCCESS;
    }
}
