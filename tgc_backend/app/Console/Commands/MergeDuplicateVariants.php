<?php

namespace App\Console\Commands;

use App\Models\ProductVariant;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Phase-1 step 05, stage 3. Merges duplicate product_variants rows that
 * `variants:find-duplicates` identified and a human has signed off on.
 *
 * Dry-run by default; nothing is written without --force. Merges exactly one
 * human-specified group of variant IDs per invocation — this command never
 * discovers or decides which rows belong together, because that judgement
 * ("is {NULL, R} the same carpet, or two different products?") is explicitly
 * not automatable. See
 * instructions/phase-1/05-variant-unique-constraint.md "Stage 3".
 *
 * Usage:
 *   php artisan variants:merge-duplicates --group=91,77 --reason="..."              (dry run)
 *   php artisan variants:merge-duplicates --group=91,77 --reason="..." --force      (writes)
 *
 * DO NOT run --force against production without:
 *   1. instructions/phase-1/04 shipped and the duplicate count verified flat
 *      for several days (see that file's "Depends on / blocks").
 *   2. A full mysqldump taken and restore-tested.
 *   3. A signed-off decision, in writing, for this specific group.
 *   4. The app in maintenance mode or a genuine low-traffic window — this is
 *      NOT safe to run against a live writer.
 */
class MergeDuplicateVariants extends Command
{
    protected $signature = 'variants:merge-duplicates
                            {--group= : Comma-separated variant IDs to merge, e.g. 91,77}
                            {--survivor= : Variant ID to keep. Defaults to the lowest ID in --group.}
                            {--reason= : Required with --force. Who decided, and why.}
                            {--force : Actually write. Without this, reports only.}';

    protected $description = 'Merge a human-specified group of duplicate product_variants rows into one survivor.';

    /** All five FK tables pointing at product_variants, all restrictOnDelete. Verify against
     *  information_schema before trusting this list — see the instructions file. */
    private const FK_TABLES = [
        'stock_movements',
        'order_items',
        'shipment_items',
        'production_batch_items',
        'warehouse_document_items',
    ];

    public function handle(): int
    {
        $groupOption = $this->option('group');
        if (! $groupOption) {
            $this->error('--group=<comma-separated variant ids> is required. Run variants:find-duplicates first.');

            return self::FAILURE;
        }

        $variantIds = array_map('intval', array_filter(explode(',', $groupOption)));
        if (count($variantIds) < 2) {
            $this->error('--group needs at least two variant IDs.');

            return self::FAILURE;
        }

        $variants = ProductVariant::whereIn('id', $variantIds)->orderBy('id')->get();
        if ($variants->count() !== count($variantIds)) {
            $this->error('One or more variant IDs in --group do not exist.');

            return self::FAILURE;
        }

        $survivorId = $this->option('survivor') ? (int) $this->option('survivor') : $variants->min('id');
        if (! $variants->pluck('id')->contains($survivorId)) {
            $this->error('--survivor must be one of the IDs in --group.');

            return self::FAILURE;
        }
        $loserIds = $variants->pluck('id')->reject(fn ($id) => $id === $survivorId)->values()->all();

        $this->info("Survivor: {$survivorId}. Losers: " . implode(', ', $loserIds));

        // ── Barcode check — a printed physical label pointing at a loser
        //    would 404 on scan once the row is deleted. ─────────────────────
        foreach ($variants as $v) {
            if ((int) $v->id !== $survivorId && $v->barcode_value) {
                $this->warn(
                    "Variant {$v->id} (a loser) has barcode_value={$v->barcode_value}. If this is "
                    . 'printed on a physical label, deleting this row breaks that scan. Confirm no '
                    . 'printed label carries this barcode before merging — see the instructions file, '
                    . '"barcode_value is unique and the loser holds one".'
                );
            }
        }

        $before = $this->stockFor($variantIds);
        $this->info('Stock before (sum across the whole group): ' . $before);

        $counts = [];
        foreach (self::FK_TABLES as $table) {
            foreach ($loserIds as $loserId) {
                $n = DB::table($table)->where('product_variant_id', $loserId)->count();
                if ($n > 0) {
                    $counts[$table] = ($counts[$table] ?? 0) + $n;
                }
            }
        }

        $this->table(['table', 'rows that would be repointed'], collect($counts)->map(fn ($n, $t) => [$t, $n])->values());

        if (! $this->option('force')) {
            $this->newLine();
            $this->comment('Dry run only. Nothing written. Re-run with --force --reason="..." to merge.');

            return self::SUCCESS;
        }

        $reason = $this->option('reason');
        if (! $reason) {
            $this->error('--reason is required with --force — the mapping table records who decided and why.');

            return self::FAILURE;
        }

        if (! $this->confirm(
            "This will DELETE variant(s) " . implode(', ', $loserIds) . " and repoint their rows to {$survivorId}. "
            . 'Have you taken a full mysqldump and confirmed no printed barcode is affected? Proceed?',
            false
        )) {
            $this->comment('Aborted.');

            return self::SUCCESS;
        }

        DB::transaction(function () use ($survivorId, $loserIds, $reason, $before): void {
            foreach ($loserIds as $loserId) {
                $snapshot = DB::table('product_variants')->where('id', $loserId)->first();

                $repointed = [];
                foreach (self::FK_TABLES as $table) {
                    $repointed[$table] = DB::table($table)
                        ->where('product_variant_id', $loserId)
                        ->update(['product_variant_id' => $survivorId]);
                }

                DB::table('product_variant_merges')->insert([
                    'loser_variant_id'    => $loserId,
                    'survivor_variant_id' => $survivorId,
                    'loser_snapshot'      => json_encode($snapshot),
                    'repointed_counts'    => json_encode($repointed),
                    'reason'              => $reason,
                    'created_at'          => now(),
                    'updated_at'          => now(),
                ]);

                // restrictOnDelete on every FK above: this throws if any table
                // was missed. That is the guard — do not loosen the FK.
                DB::table('product_variants')->where('id', $loserId)->delete();
            }

            $after = $this->stockFor([$survivorId]);
            if ($before !== $after) {
                throw new \RuntimeException(
                    "Merge changed total stock: before={$before}, after={$after}. Rolling back."
                );
            }
        });

        $this->info('Merge complete. Stock invariant held: ' . $this->stockFor([$survivorId]) . ' (unchanged from before).');
        $this->comment('product_variant_merges has the snapshot — do not drop that table.');

        return self::SUCCESS;
    }

    private function stockFor(array $variantIds): int
    {
        $row = DB::table('stock_movements')
            ->whereIn('product_variant_id', $variantIds)
            ->selectRaw(
                "COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE 0 END), 0)"
                . " - COALESCE(SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END), 0) AS stock"
            )
            ->first();

        return (int) ($row->stock ?? 0);
    }
}
