<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Stock movements, warehouse document items, and sale items must all carry
 * the product_size that was involved in the transaction.  Nullable so
 * existing historical rows (before sizes were introduced) don't break.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->foreignId('product_size_id')
                ->nullable()
                ->after('product_id')
                ->constrained('product_sizes')
                ->nullOnDelete();

            $table->index('product_size_id');
        });

        Schema::table('sale_items', function (Blueprint $table) {
            $table->foreignId('product_size_id')
                ->nullable()
                ->after('product_id')
                ->constrained('product_sizes')
                ->nullOnDelete();

            $table->index('product_size_id');
        });

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->foreignId('product_size_id')
                ->nullable()
                ->after('product_id')
                ->constrained('product_sizes')
                ->nullOnDelete();

            // Granular stock reporting per product+size combination
            $table->index(['product_id', 'product_size_id', 'movement_type']);
        });
    }

    public function down(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropIndex(['product_id', 'product_size_id', 'movement_type']);
            $table->dropForeign(['product_size_id']);
            $table->dropColumn('product_size_id');
        });

        Schema::table('sale_items', function (Blueprint $table) {
            $table->dropIndex(['product_size_id']);
            $table->dropForeign(['product_size_id']);
            $table->dropColumn('product_size_id');
        });

        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->dropIndex(['product_size_id']);
            $table->dropForeign(['product_size_id']);
            $table->dropColumn('product_size_id');
        });
    }
};
