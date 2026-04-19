<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Embed size (length × width) directly on product_variants, eliminating the
 * separate product_sizes lookup table.
 *
 * Steps:
 *  1. Add nullable length / width columns to product_variants.
 *  2. Back-fill from the joined product_sizes data.
 *  3. Drop the product_size_id FK + column from product_variants.
 *  4. Drop the redundant product_size_id columns from
 *     warehouse_document_items and stock_movements (added in an earlier migration).
 *  5. Drop the product_sizes table itself.
 */
return new class extends Migration
{
    public function up(): void
    {
        // ── 1. Add new columns (guard against partial previous run) ──────
        Schema::table('product_variants', function (Blueprint $table) {
            if (!Schema::hasColumn('product_variants', 'length')) {
                $table->integer('length')->nullable()->after('product_color_id');
            }
            if (!Schema::hasColumn('product_variants', 'width')) {
                $table->integer('width')->nullable()->after('length');
            }
        });

        // ── 2. Back-fill from product_sizes ───────────────────────────────
        DB::statement('
            UPDATE product_variants pv
            INNER JOIN product_sizes ps ON ps.id = pv.product_size_id
            SET pv.length = ps.length, pv.width = ps.width
        ');

        // ── 3. Drop product_size_id from product_variants ─────────────────
        if (Schema::hasColumn('product_variants', 'product_size_id')) {
            Schema::table('product_variants', function (Blueprint $table) {
                // Drop both FKs first — product_color_id's FK uses variants_color_size_idx
                // as its supporting index, so the index can't be dropped while it exists.
                $table->dropForeign(['product_color_id']);
                $table->dropForeign(['product_size_id']);

                $table->dropIndex('variants_color_size_idx');
                $table->dropColumn('product_size_id');

                // New index on (color, length, width) — also serves as the supporting
                // index for the re-added product_color_id FK below.
                $table->index(['product_color_id', 'length', 'width'], 'variants_color_size_idx');

                $table->foreign('product_color_id')
                    ->references('id')
                    ->on('product_colors')
                    ->restrictOnDelete();
            });
        }

        // ── 4. Drop product_size_id from warehouse_document_items ─────────
        if (Schema::hasColumn('warehouse_document_items', 'product_size_id')) {
            Schema::table('warehouse_document_items', function (Blueprint $table) {
                try {
                    $table->dropIndex(['product_size_id']);
                } catch (\Throwable) {}
                $table->dropForeign(['product_size_id']);
                $table->dropColumn('product_size_id');
            });
        }

        // ── 4b. Drop product_size_id from stock_movements ─────────────────
        if (Schema::hasColumn('stock_movements', 'product_size_id')) {
            Schema::table('stock_movements', function (Blueprint $table) {
                try {
                    $table->dropIndex(['product_id', 'product_size_id', 'movement_type']);
                } catch (\Throwable) {}
                $table->dropForeign(['product_size_id']);
                $table->dropColumn('product_size_id');
            });
        }

        // ── 5. Drop the lookup table ──────────────────────────────────────
        Schema::dropIfExists('product_sizes');
    }

    public function down(): void
    {
        throw new \RuntimeException('This migration cannot be reversed automatically.');
    }
};
