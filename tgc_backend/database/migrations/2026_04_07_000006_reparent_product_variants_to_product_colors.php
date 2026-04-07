<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Re-parent product_variants:
     *   product_id  →  product_color_id
     *
     * Chain: products → product_colors → product_variants → stock_movements / etc.
     *
     * For existing variants, we resolve via
     *   product_variants.product_id  →  product_colors.product_id
     * (picking the first product_color for that product, because the old schema
     * had no color concept at the variant level).
     */
    public function up(): void
    {
        // 1. Add nullable FK column
        Schema::table('product_variants', function (Blueprint $table) {
            $table->unsignedBigInteger('product_color_id')->nullable()->after('id');
        });

        // 2. Backfill: assign each variant to its product's first product_color
        $variants = DB::table('product_variants')->select('id', 'product_id')->get();

        foreach ($variants as $variant) {
            $productColorId = DB::table('product_colors')
                ->where('product_id', $variant->product_id)
                ->value('id');

            if ($productColorId) {
                DB::table('product_variants')
                    ->where('id', $variant->id)
                    ->update(['product_color_id' => $productColorId]);
            }
        }

        // 3. Make NOT NULL
        DB::statement('ALTER TABLE product_variants MODIFY product_color_id BIGINT UNSIGNED NOT NULL');

        // 4. Drop old product_id FK + column, add new FK
        Schema::table('product_variants', function (Blueprint $table) {
            $table->dropIndex('variants_product_size_idx');
            $table->dropForeign(['product_id']);
            $table->dropColumn('product_id');

            $table->foreign('product_color_id')
                ->references('id')
                ->on('product_colors')
                ->restrictOnDelete();

            $table->index(['product_color_id', 'product_size_id'], 'variants_color_size_idx');
        });
    }

    public function down(): void
    {
        Schema::table('product_variants', function (Blueprint $table) {
            $table->unsignedBigInteger('product_id')->nullable()->after('id');
        });

        // Restore product_id from product_color → product
        $variants = DB::table('product_variants')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->select('product_variants.id', 'product_colors.product_id')
            ->get();

        foreach ($variants as $variant) {
            DB::table('product_variants')
                ->where('id', $variant->id)
                ->update(['product_id' => $variant->product_id]);
        }

        DB::statement('ALTER TABLE product_variants MODIFY product_id BIGINT UNSIGNED NOT NULL');

        Schema::table('product_variants', function (Blueprint $table) {
            $table->dropIndex('variants_color_size_idx');
            $table->dropForeign(['product_color_id']);
            $table->dropColumn('product_color_id');

            $table->foreign('product_id')
                ->references('id')
                ->on('products')
                ->restrictOnDelete();

            $table->index(['product_id', 'product_size_id'], 'variants_product_size_idx');
        });
    }
};
