<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Moves SKU generation from products down to product_variants.
 *
 * New SKU format: TGC-{name}-Q{quality_id}-T{type_id}-{color}-{size}
 *   e.g.  TGC-7126-Q1-T2-KREM-200x300
 *
 * Steps:
 *  1. Add nullable sku_code to product_variants.
 *  2. Backfill by joining through product_colors → products / colors / product_sizes.
 *  3. Make NOT NULL + UNIQUE (raw ALTER).
 *  4. Drop sku_code from products.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ── 1. Add nullable sku_code to product_variants ──────────────────────

        Schema::table('product_variants', function (Blueprint $table) {
            $table->string('sku_code')->nullable()->after('barcode_value');
        });

        // ── 2. Backfill ───────────────────────────────────────────────────────

        DB::statement("
            UPDATE product_variants pv
            INNER JOIN product_colors pc ON pc.id = pv.product_color_id
            INNER JOIN products p        ON p.id  = pc.product_id
            INNER JOIN colors c          ON c.id  = pc.color_id
            LEFT  JOIN product_sizes ps  ON ps.id = pv.product_size_id
            SET pv.sku_code = CONCAT(
                'TGC-',
                UPPER(REPLACE(REPLACE(REPLACE(LOWER(TRIM(p.name)), ' ', '_'), '-', '_'), '/', '_')),
                CASE WHEN p.product_quality_id IS NOT NULL THEN CONCAT('-Q', p.product_quality_id) ELSE '' END,
                CASE WHEN p.product_type_id    IS NOT NULL THEN CONCAT('-T', p.product_type_id)    ELSE '' END,
                '-', UPPER(REPLACE(REPLACE(LOWER(TRIM(c.name)), ' ', '_'), '-', '_')),
                CASE WHEN ps.id IS NOT NULL THEN CONCAT('-', ps.length, 'x', ps.width) ELSE '' END
            )
        ");

        // ── 3. NOT NULL + UNIQUE ───────────────────────────────────────────────

        DB::statement('ALTER TABLE `product_variants` MODIFY `sku_code` VARCHAR(255) NOT NULL');
        DB::statement('ALTER TABLE `product_variants` ADD UNIQUE INDEX `product_variants_sku_code_unique` (`sku_code`)');

        // ── 4. Drop sku_code from products ────────────────────────────────────

        Schema::table('products', function (Blueprint $table) {
            $indexes = DB::select("SHOW INDEX FROM `products` WHERE Key_name = 'products_sku_code_unique'");
            if (! empty($indexes)) {
                $table->dropUnique(['sku_code']);
            }

            $table->dropColumn('sku_code');
        });
    }

    public function down(): void
    {
        // Re-add sku_code to products (nullable to avoid row errors on rollback)
        Schema::table('products', function (Blueprint $table) {
            $table->string('sku_code')->nullable()->unique()->after('uuid');
        });

        // Remove sku_code from product_variants
        Schema::table('product_variants', function (Blueprint $table) {
            $table->dropUnique('product_variants_sku_code_unique');
            $table->dropColumn('sku_code');
        });
    }
};
