<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('raw_materials', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->string('type');
            $table->enum('unit', ['piece', 'sqm', 'kg', 'meter'])->default('piece');
            $table->timestamps();

            $table->unique(['name', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('raw_materials');
    }
};
