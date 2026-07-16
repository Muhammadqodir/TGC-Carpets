<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * There is no currency, exchange_rate, VAT, or discount concept anywhere
 * in the backend today — every number is a bare decimal everyone agrees
 * to imagine is USD. See instructions/phase-3/04-currency-vat-discount.md.
 *
 * DEFAULT 'USD' / 1 / 0 is the backfill for every existing row, and it is
 * the correct one: every historical shipment was already assumed to be
 * USD with no VAT, so declaring that assumption explicit changes no
 * value. Run the pre-deploy MIN/MAX/AVG sanity check in
 * reconcile-before-deploy.sql before trusting that assumption on a given
 * environment — if a price is already in the millions, someone has typed
 * UZS into a field the invoice labels "$", and that is a data-correction
 * job to do before this ships, not after.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table): void {
            $table->char('currency', 3)->default('USD')->after('order_id');
            $table->decimal('exchange_rate', 18, 8)->default(1)->after('currency');
            // Header-level: the printed hisob-faktura carries one VAT rate
            // per document, not one per line. See the instruction file's
            // "The change" #3 for the header-vs-line decision and the
            // legal caveat on which one Uzbek tax rules actually require.
            $table->decimal('vat_rate', 6, 4)->default(0)->after('exchange_rate');
            $table->decimal('vat_amount', 14, 2)->default(0)->after('vat_rate');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->char('currency', 3)->default('USD')->after('amount');
            $table->decimal('exchange_rate', 18, 8)->default(1)->after('currency');
        });
    }

    public function down(): void
    {
        Schema::table('shipments', function (Blueprint $table): void {
            $table->dropColumn(['currency', 'exchange_rate', 'vat_rate', 'vat_amount']);
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->dropColumn(['currency', 'exchange_rate']);
        });
    }
};
