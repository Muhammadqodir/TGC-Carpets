<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('defect_document_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('defect_document_id')
                  ->constrained('defect_documents')
                  ->cascadeOnDelete();
            $table->foreignId('production_batch_item_id')
                  ->constrained('production_batch_items');
            $table->unsignedInteger('quantity');
            $table->timestamps();

            $table->index('defect_document_id');
            $table->index('production_batch_item_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('defect_document_items');
    }
};
