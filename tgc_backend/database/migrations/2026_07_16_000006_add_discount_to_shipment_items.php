<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Discount lives at the LINE level, not apportioned down from a header
 * figure — apportionment is where cents vanish. See
 * instructions/phase-3/04-currency-vat-discount.md "The change" #2.
 *
 * discount_amount is the computed, frozen cash value in the shipment's
 * currency, stored rather than recomputed at read time — an old invoice
 * must reprint identically after a future rounding-rule change.
 *
 * DEFAULT 'none' / 0 / 0 backfills every existing shipment_items row to
 * "no discount was ever applied", which is true: no discount concept
 * existed before this column did.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipment_items', function (Blueprint $table): void {
            $table->enum('discount_type', ['none', 'percent', 'amount'])->default('none')->after('price');
            $table->decimal('discount_value', 12, 4)->default(0)->after('discount_type');
            $table->decimal('discount_amount', 14, 2)->default(0)->after('discount_value');
        });
    }

    public function down(): void
    {
        Schema::table('shipment_items', function (Blueprint $table): void {
            $table->dropColumn(['discount_type', 'discount_value', 'discount_amount']);
        });
    }
};
