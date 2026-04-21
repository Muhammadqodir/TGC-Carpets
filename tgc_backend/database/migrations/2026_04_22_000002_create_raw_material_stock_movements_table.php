<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('raw_material_stock_movements', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('material_id')
                ->constrained('raw_materials')
                ->restrictOnDelete();
            $table->foreignId('user_id')
                ->constrained('users')
                ->restrictOnDelete();
            $table->dateTime('date_time');
            $table->enum('type', ['received', 'spent']);
            $table->double('quantity');
            $table->string('notes')->nullable();
            $table->timestamps();

            $table->index('material_id');
            $table->index('date_time');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('raw_material_stock_movements');
    }
};
