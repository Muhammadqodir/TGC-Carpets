<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * stock_movements is the auditable ledger of all inventory changes.
     * It is created LAST because it references warehouse_documents.
     * All FK references are nullable so historical audit records survive
     * if a source document is ever deleted.
     */
    public function up(): void
    {
        Schema::create('stock_movements', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();

            $table->foreignId('product_id')
                ->constrained('products')
                ->restrictOnDelete();

            // Source of the movement — at most one will be set per row
            $table->foreignId('warehouse_document_id')
                ->nullable()
                ->constrained('warehouse_documents')
                ->nullOnDelete();

            // Denormalized for faster reporting without joins
            $table->foreignId('client_id')
                ->nullable()
                ->constrained('clients')
                ->nullOnDelete();

            $table->foreignId('user_id')
                ->constrained('users')
                ->restrictOnDelete();

            // in | out | adjustment | return
            $table->string('movement_type')->index();

            // Always stored as a positive integer; direction is determined by movement_type
            $table->integer('quantity');

            $table->timestamp('movement_date')->index();
            $table->text('notes')->nullable();
            $table->timestamps();

            // Composite indexes for stock reporting queries
            $table->index(['product_id', 'movement_date']);
            $table->index(['product_id', 'movement_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_movements');
    }
};
