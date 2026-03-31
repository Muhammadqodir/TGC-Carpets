<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('name');
            $table->string('sku_code')->unique()->index();
            $table->string('barcode')->nullable()->unique();
            $table->integer('length');
            $table->integer('width');
            $table->string('quality')->index();
            $table->integer('density');
            $table->string('color')->index();
            $table->string('edge');
            $table->string('unit')->default('piece');
            $table->string('status')->default('active')->index();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
