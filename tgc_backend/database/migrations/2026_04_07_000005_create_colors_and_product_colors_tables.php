<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Normalise product colours:
     *
     * 1. Create `colors` — a reference table of unique colour names.
     * 2. Create `product_colors` — the combination of a product + colour
     *    (holds the image that was previously on the products table).
     * 3. Migrate existing data from `products.color` / `products.image`
     *    into the new structure.
     * 4. Drop the `color` and `image` columns from `products`.
     */
    public function up(): void
    {
        // ── 1. colors ─────────────────────────────────────────────────────────
        Schema::create('colors', function (Blueprint $table) {
            $table->id();
            $table->string('name', 100)->unique();
            $table->timestamps();
        });

        // ── 2. product_colors ─────────────────────────────────────────────────
        Schema::create('product_colors', function (Blueprint $table) {
            $table->id();

            $table->foreignId('product_id')
                ->constrained('products')
                ->cascadeOnDelete();

            $table->foreignId('color_id')
                ->constrained('colors')
                ->restrictOnDelete();

            $table->string('image')->nullable();
            $table->timestamps();

            $table->unique(['product_id', 'color_id'], 'product_color_unique');
        });

        // ── 3. Backfill from products.color / products.image ──────────────────
        $products = DB::table('products')
            ->select('id', 'color', 'image')
            ->whereNotNull('color')
            ->get();

        $colorCache = [];

        foreach ($products as $product) {
            $colorName = trim($product->color);
            if ($colorName === '') {
                continue;
            }

            if (! isset($colorCache[$colorName])) {
                $colorId = DB::table('colors')
                    ->where('name', $colorName)
                    ->value('id');

                if (! $colorId) {
                    $colorId = DB::table('colors')->insertGetId([
                        'name'       => $colorName,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }

                $colorCache[$colorName] = $colorId;
            }

            DB::table('product_colors')->insertOrIgnore([
                'product_id' => $product->id,
                'color_id'   => $colorCache[$colorName],
                'image'      => $product->image,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        // ── 4. Drop old columns from products ────────────────────────────────
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['color', 'image']);
        });
    }

    public function down(): void
    {
        // Re-add columns first
        Schema::table('products', function (Blueprint $table) {
            $table->string('color', 100)->nullable()->after('product_quality_id');
            $table->string('image')->nullable()->after('status');
        });

        // Copy back
        $productColors = DB::table('product_colors')
            ->join('colors', 'colors.id', '=', 'product_colors.color_id')
            ->select('product_colors.product_id', 'colors.name as color', 'product_colors.image')
            ->get();

        foreach ($productColors as $pc) {
            DB::table('products')
                ->where('id', $pc->product_id)
                ->update([
                    'color' => $pc->color,
                    'image' => $pc->image,
                ]);
        }

        Schema::dropIfExists('product_colors');
        Schema::dropIfExists('colors');
    }
};
