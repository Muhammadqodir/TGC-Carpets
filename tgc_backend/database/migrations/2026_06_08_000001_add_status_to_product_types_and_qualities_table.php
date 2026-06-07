<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('product_types', function (Blueprint $table) {
            $table->string('status')->default('active')->after('type');
        });

        Schema::table('product_qualities', function (Blueprint $table) {
            $table->string('status')->default('active')->after('density');
        });
    }

    public function down(): void
    {
        Schema::table('product_types', function (Blueprint $table) {
            $table->dropColumn('status');
        });

        Schema::table('product_qualities', function (Blueprint $table) {
            $table->dropColumn('status');
        });
    }
};
