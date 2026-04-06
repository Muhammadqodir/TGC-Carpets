<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->foreignId('product_quality_id')
                ->nullable()
                ->after('product_type_id')
                ->constrained('product_qualities')
                ->nullOnDelete();

            $table->index('product_quality_id');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['quality', 'density']);
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('quality')->default('')->after('product_type_id');
            $table->integer('density')->default(0)->after('quality');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropForeign(['product_quality_id']);
            $table->dropIndex(['product_quality_id']);
            $table->dropColumn('product_quality_id');
        });
    }
};
