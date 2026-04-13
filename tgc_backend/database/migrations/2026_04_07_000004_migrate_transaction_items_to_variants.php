<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Moves warehouse_document_items and stock_movements away from
 * the separate (product_id, product_size_id) columns to a single
 * product_variant_id reference.
 *
 * Steps:
 *  1. Add nullable product_variant_id FK to both tables.
 *  2. Backfill: create a ProductVariant row for every distinct
 *     (product_id, product_size_id) found in the transaction tables, then
 *     stamp each transaction row with the matching variant ID.
 *  3. Make product_variant_id NOT NULL (raw ALTER — avoids doctrine/dbal
 *     dependency and works on MySQL/MariaDB).
 *  4. Drop the now-redundant product_id and product_size_id columns.
 *  5. Add reporting indexes on the new column.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ── 1. Add nullable variant FK ─────────────────────────────────────────

        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->foreignId('product_variant_id')
                ->nullable()
                ->after('product_id')
                ->constrained('product_variants')
                ->restrictOnDelete();
        });

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->foreignId('product_variant_id')
                ->nullable()
                ->after('product_id')
                ->constrained('product_variants')
                ->restrictOnDelete();
        });

        // ── 2. Backfill variants and stamp transaction rows ────────────────────

        $now    = now()->toDateTimeString();
        $tables = ['warehouse_document_items', 'stock_movements'];

        // Collect all unique (product_id, product_size_id) combos
        $combos = collect();
        foreach ($tables as $tbl) {
            DB::table($tbl)->select('product_id', 'product_size_id')->get()
                ->each(fn ($r) => $combos->push($r));
        }

        $unique = $combos->unique(fn ($r) => $r->product_id . '-' . ($r->product_size_id ?? 'NULL'));

        foreach ($unique as $row) {
            $exists = DB::table('product_variants')
                ->where('product_id', $row->product_id)
                ->where(function ($q) use ($row) {
                    $row->product_size_id !== null
                        ? $q->where('product_size_id', $row->product_size_id)
                        : $q->whereNull('product_size_id');
                })
                ->exists();

            if ($exists) {
                continue;
            }

            $variantId = DB::table('product_variants')->insertGetId([
                'product_id'      => $row->product_id,
                'product_size_id' => $row->product_size_id,
                'barcode_value'   => null,
                'created_at'      => $now,
                'updated_at'      => $now,
            ]);

            DB::table('product_variants')->where('id', $variantId)->update([
                'barcode_value' => 'TGC-VAR-' . str_pad($variantId, 8, '0', STR_PAD_LEFT),
            ]);
        }

        // Stamp each transaction row
        foreach ($tables as $tbl) {
            DB::statement("
                UPDATE `{$tbl}` t
                INNER JOIN product_variants pv
                    ON  pv.product_id = t.product_id
                    AND (
                            (t.product_size_id IS NULL     AND pv.product_size_id IS NULL)
                         OR (t.product_size_id IS NOT NULL AND pv.product_size_id = t.product_size_id)
                        )
                SET t.product_variant_id = pv.id
                WHERE t.product_variant_id IS NULL
            ");
        }

        // ── 3. Make NOT NULL (raw ALTER avoids doctrine/dbal requirement) ──────

        DB::statement('ALTER TABLE `warehouse_document_items` MODIFY `product_variant_id` BIGINT UNSIGNED NOT NULL');
        DB::statement('ALTER TABLE `stock_movements`          MODIFY `product_variant_id` BIGINT UNSIGNED NOT NULL');

        // ── 4. Drop old columns ───────────────────────────────────────────────

        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->dropForeign(['product_size_id']);
            $table->dropForeign(['product_id']);
            $this->dropIndexIfExists($table, 'warehouse_document_items_product_size_id_index');
            $table->dropColumn(['product_id', 'product_size_id']);
        });

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropForeign(['product_size_id']);
            $table->dropForeign(['product_id']);
            $this->dropIndexIfExists($table, 'stock_movements_product_id_product_size_id_movement_type_index');
            $this->dropIndexIfExists($table, 'stock_movements_product_id_movement_date_index');
            $this->dropIndexIfExists($table, 'stock_movements_product_id_movement_type_index');
            $table->dropColumn(['product_id', 'product_size_id']);
        });

        // ── 5. Add reporting indexes ──────────────────────────────────────────

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->index(['product_variant_id', 'movement_type'],  'sm_variant_type_idx');
            $table->index(['product_variant_id', 'movement_date'],  'sm_variant_date_idx');
        });
    }

    public function down(): void
    {
        // Re-add old columns (nullable so existing rows don't break)
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->foreignId('product_id')->nullable()->after('id')->constrained('products')->restrictOnDelete();
            $table->foreignId('product_size_id')->nullable()->after('product_id')->constrained('product_sizes')->nullOnDelete();
            $table->dropForeign(['product_variant_id']);
            $table->dropColumn('product_variant_id');
        });

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropIndex('sm_variant_type_idx');
            $table->dropIndex('sm_variant_date_idx');
            $table->foreignId('product_id')->nullable()->after('uuid')->constrained('products')->restrictOnDelete();
            $table->foreignId('product_size_id')->nullable()->after('product_id')->constrained('product_sizes')->nullOnDelete();
            $table->dropForeign(['product_variant_id']);
            $table->dropColumn('product_variant_id');
        });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function dropIndexIfExists(Blueprint $table, string $indexName): void
    {
        $indexes = DB::select("SHOW INDEX FROM `{$table->getTable()}` WHERE Key_name = ?", [$indexName]);
        if (! empty($indexes)) {
            $table->dropIndex($indexName);
        }
    }
};
