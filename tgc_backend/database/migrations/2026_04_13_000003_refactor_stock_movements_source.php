<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Replace the flat sale_id + client_id FKs on stock_movements with a
 * polymorphic source (source_type + source_id).
 *
 * Rationale:
 *  - sale_id and warehouse_document_id were used redundantly (SaleService
 *    sets both on the same movement row).
 *  - client_id was a denormalized copy used only for quick reporting.
 *  - source_type / source_id generalises the "what triggered this movement"
 *    concept to all future sources (production, sale, other).
 *
 * warehouse_document_id is intentionally kept — every movement must still
 * reference the document that carries the stock paperwork.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropForeign(['sale_id']);
            $table->dropColumn('sale_id');

            $table->dropForeign(['client_id']);
            $table->dropColumn('client_id');

            // Drop the composite index that included product_size_id if it exists.
            $indexes = collect(\Illuminate\Support\Facades\Schema::getIndexes('stock_movements'))
                ->pluck('name');
            if ($indexes->contains('stock_movements_product_id_product_size_id_movement_type_index')) {
                $table->dropIndex(['product_id', 'product_size_id', 'movement_type']);
            }

            $table->string('source_type')->nullable()->after('warehouse_document_id');
            $table->unsignedBigInteger('source_id')->nullable()->after('source_type');

            $table->index(['source_type', 'source_id']);
        });
    }

    public function down(): void
    {
        Schema::table('stock_movements', function (Blueprint $table) {
            $table->dropIndex(['source_type', 'source_id']);
            $table->dropColumn(['source_type', 'source_id']);

            $table->foreignId('sale_id')
                ->nullable()
                ->after('warehouse_document_id')
                ->constrained('sales')
                ->nullOnDelete();

            $table->foreignId('client_id')
                ->nullable()
                ->constrained('clients')
                ->nullOnDelete();
        });
    }
};
