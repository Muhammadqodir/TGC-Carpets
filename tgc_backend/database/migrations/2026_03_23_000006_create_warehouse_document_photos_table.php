<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('warehouse_document_photos', function (Blueprint $table) {
            $table->id();

            $table->foreignId('warehouse_document_id')
                ->constrained('warehouse_documents')
                ->cascadeOnDelete();

            $table->string('path');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('warehouse_document_photos');
    }
};
