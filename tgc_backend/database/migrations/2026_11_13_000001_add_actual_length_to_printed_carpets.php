<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The real length of each carpet of a type whose length varies from roll to
 * roll (Kovrolin): its size names a nominal length, e.g. 400×3000, and the
 * roll that comes off the machine is a few metres longer or shorter. The
 * label printer types it in before printing.
 *
 * Purely additive: every length column is nullable. Carpets printed before
 * this, carpets of fixed-size types and prints from old app builds have none,
 * and everything that reads it falls back to the size's nominal length.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('product_types', function (Blueprint $table): void {
            $table->boolean('has_variable_length')->default(false)->after('is_printable');
        });

        DB::table('product_types')->where('type', 'Kovrolin')->update(['has_variable_length' => true]);

        Schema::table('production_units', function (Blueprint $table): void {
            $table->unsignedInteger('length_cm')->nullable()->after('carpet_number');
        });

        // On the ledger too, so production m² sums without joining units.
        Schema::table('production_events', function (Blueprint $table): void {
            $table->unsignedInteger('length_cm')->nullable()->after('quantity');
        });

        Schema::table('label_reprints', function (Blueprint $table): void {
            $table->unsignedInteger('length_cm')->nullable()->after('carpet_number');
        });
    }

    public function down(): void
    {
        Schema::table('label_reprints', function (Blueprint $table): void {
            $table->dropColumn('length_cm');
        });

        Schema::table('production_events', function (Blueprint $table): void {
            $table->dropColumn('length_cm');
        });

        Schema::table('production_units', function (Blueprint $table): void {
            $table->dropColumn('length_cm');
        });

        Schema::table('product_types', function (Blueprint $table): void {
            $table->dropColumn('has_variable_length');
        });
    }
};
