<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Replace the flat client_id FK on warehouse_documents with a polymorphic
 * source (source_type + source_id).
 *
 * Allowed source_type values: 'production' | 'sale' | 'other'
 * source_id references the PK of the corresponding entity.
 * Both columns are nullable — manually-created documents may have no source.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table) {
            // Drop the old FK constraint before dropping the column
            $table->dropForeign(['client_id']);
            $table->dropColumn('client_id');

            $table->string('source_type')->nullable()->after('type');
            $table->unsignedBigInteger('source_id')->nullable()->after('source_type');

            $table->index(['source_type', 'source_id']);
        });
    }

    public function down(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table) {
            $table->dropIndex(['source_type', 'source_id']);
            $table->dropColumn(['source_type', 'source_id']);

            $table->foreignId('client_id')
                ->nullable()
                ->after('type')
                ->constrained('clients')
                ->nullOnDelete();
        });
    }
};
