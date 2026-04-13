<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Refactor stock_movements to remove the old source columns and tie every
 * movement directly to the warehouse_document_item that caused it.
 *
 * Changes:
 *  - Drop sale_id, client_id (legacy denormalized columns)
 *  - Drop warehouse_document_id (document-level reference replaced by item-level)
 *  - Add warehouse_document_item_id (FK → warehouse_document_items, nullOnDelete)
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            // Drop legacy FKs and columns
            $table->dropForeign(['sale_id']);
            $table->dropColumn('sale_id');

            $table->dropForeign(['client_id']);
            $table->dropColumn('client_id');

            $table->dropForeign(['warehouse_document_id']);
            $table->dropColumn('warehouse_document_id');

            // Drop stale composite index if it was created by an earlier migration
            $indexes = collect(\Illuminate\Support\Facades\Schema::getIndexes('stock_movements'))
                ->pluck('name');
            if ($indexes->contains('stock_movements_product_id_product_size_id_movement_type_index')) {
                $table->dropIndex(['product_id', 'product_size_id', 'movement_type']);
            }

            // New item-level reference
            $table->foreignId('warehouse_document_item_id')
                ->nullable()
                ->after('product_variant_id')
                ->constrained('warehouse_document_items')
                ->nullOnDelete();

            $table->index('warehouse_document_item_id');
        });
    }

    public function down(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropIndex(['warehouse_document_item_id']);
            $table->dropForeign(['warehouse_document_item_id']);
            $table->dropColumn('warehouse_document_item_id');

            $table->foreignId('warehouse_document_id')
                ->nullable()
                ->after('product_variant_id')
                ->constrained('warehouse_documents')
                ->nullOnDelete();

            $table->foreignId('sale_id')
                ->nullable()
                ->constrained('sales')
                ->nullOnDelete();

            $table->foreignId('client_id')
                ->nullable()
                ->constrained('clients')
                ->nullOnDelete();
        });
    }
};
