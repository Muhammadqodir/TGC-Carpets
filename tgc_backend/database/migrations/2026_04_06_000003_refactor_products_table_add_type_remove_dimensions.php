<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->foreignId('product_type_id')
                ->nullable()
                ->after('barcode')
                ->constrained('product_types')
                ->nullOnDelete();

            $table->index('product_type_id');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['length', 'width']);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->integer('length')->default(0)->after('barcode');
            $table->integer('width')->default(0)->after('length');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropForeign(['product_type_id']);
            $table->dropIndex(['product_type_id']);
            $table->dropColumn('product_type_id');
        });
    }
};
