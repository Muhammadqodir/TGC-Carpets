<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add polymorphic source columns to warehouse_document_items so that each
 * item can be traced back to either a shipment_item or a
 * production_batch_item.
 *
 * source_type: 'shipment_item' | 'production_batch_item'
 * source_id:   FK to the PK of the corresponding table (not enforced by DB
 *              due to polymorphism, but enforced at the service layer).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->string('source_type')->nullable()->after('quantity');
            $table->unsignedBigInteger('source_id')->nullable()->after('source_type');

            $table->index(['source_type', 'source_id'], 'wdi_source_index');
        });
    }

    public function down(): void
    {
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->dropIndex('wdi_source_index');
            $table->dropColumn(['source_type', 'source_id']);
        });
    }
};
