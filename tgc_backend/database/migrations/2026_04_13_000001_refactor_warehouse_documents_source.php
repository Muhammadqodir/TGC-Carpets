<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Remove the legacy client_id FK from warehouse_documents.
 * Source tracking is no longer held at the document level; it is moved
 * to the warehouse_document_items table (source_type / source_id).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table) {
            $table->dropForeign(['client_id']);
            $table->dropColumn('client_id');
        });
    }

    public function down(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table) {
            $table->foreignId('client_id')
                ->nullable()
                ->after('type')
                ->constrained('clients')
                ->nullOnDelete();
        });
    }
};
