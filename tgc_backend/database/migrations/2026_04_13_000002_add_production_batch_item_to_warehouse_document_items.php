<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add production_batch_item_id to warehouse_document_items so that items
 * received into the warehouse from a production batch can be traced back to
 * the exact batch item that generated them.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->foreignId('production_batch_item_id')
                ->nullable()
                ->after('quantity')
                ->constrained('production_batch_items')
                ->nullOnDelete();

            $table->index('production_batch_item_id');
        });
    }

    public function down(): void
    {
        Schema::table('warehouse_document_items', function (Blueprint $table) {
            $table->dropIndex(['production_batch_item_id']);
            $table->dropForeign(['production_batch_item_id']);
            $table->dropColumn('production_batch_item_id');
        });
    }
};
