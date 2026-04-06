<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_sizes', function (Blueprint $table) {
            $table->id();
            $table->integer('length');
            $table->integer('width');
            $table->foreignId('product_type_id')
                ->constrained('product_types')
                ->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['length', 'width', 'product_type_id']);
            $table->index('product_type_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_sizes');
    }
};
