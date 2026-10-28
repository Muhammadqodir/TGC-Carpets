<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lets an admin hide a product attribute (type, quality, colour, size, edge)
 * without first moving every product onto a replacement. A hidden attribute
 * drops out of the pickers and attribute lists, while every product, variant,
 * order and label that already uses it keeps pointing at it unchanged.
 *
 * Additive only: a nullable column, no data touched.
 */
return new class extends Migration
{
    private const TABLES = ['product_types', 'product_qualities', 'colors', 'product_sizes', 'product_edges'];

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->softDeletes();
            });
        }
    }

    public function down(): void
    {
        foreach (self::TABLES as $table) {
            Schema::table($table, function (Blueprint $t): void {
                $t->dropSoftDeletes();
            });
        }
    }
};
