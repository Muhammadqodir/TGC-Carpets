<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The unique 12-digit number printed as a barcode on every new carpet label.
 *
 * The app prints first and tells the server afterwards, so it cannot ask for a
 * number at print time. It holds blocks of numbers issued here in advance (see
 * CarpetNumberBlock) and reports which one each label got.
 *
 * Purely additive: both new columns are nullable, because every label printed
 * before this has no number, and old app builds keep printing without one.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('carpet_number_blocks', function (Blueprint $table): void {
            // The id decides which numbers the block holds; see CarpetNumberBlock.
            $table->id();
            $table->foreignId('issued_to')->constrained('users');
            $table->timestamp('created_at')->nullable();
        });

        Schema::table('production_units', function (Blueprint $table): void {
            $table->char('carpet_number', 12)->nullable()->unique()->after('serial');
        });

        Schema::table('label_reprints', function (Blueprint $table): void {
            // Not unique: reprinting a torn label repeats its carpet's number.
            $table->char('carpet_number', 12)->nullable()->index()->after('reason');
        });
    }

    public function down(): void
    {
        Schema::table('label_reprints', function (Blueprint $table): void {
            $table->dropIndex(['carpet_number']);
            $table->dropColumn('carpet_number');
        });

        Schema::table('production_units', function (Blueprint $table): void {
            $table->dropUnique(['carpet_number']);
            $table->dropColumn('carpet_number');
        });

        Schema::dropIfExists('carpet_number_blocks');
    }
};
