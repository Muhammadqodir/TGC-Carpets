<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('warehouse_document_items', function (Blueprint $table) {
            $table->id();

            $table->foreignId('warehouse_document_id')
                ->constrained('warehouse_documents')
                ->cascadeOnDelete();

            $table->foreignId('product_id')
                ->constrained('products')
                ->restrictOnDelete();

            $table->unsignedInteger('quantity');
            $table->text('notes')->nullable();
            $table->timestamps();

            // Useful for checking if a product already exists on a document
            $table->index(['warehouse_document_id', 'product_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warehouse_document_items');
    }
};
