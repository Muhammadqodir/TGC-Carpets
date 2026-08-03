<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cancelling a shipment keeps the record and marks it, rather than deleting
 * it: a shipment is a document a client was shown, and "this one was
 * cancelled by X on Y because Z" is worth more than a gap in the numbering.
 *
 * The cost of that choice is that every query deriving money or shipped
 * quantities from shipment_items must now ignore cancelled shipments —
 * `canceled_at IS NULL` — which is why the column is indexed.
 *
 * orders.created_from_shipment_id closes the loop the other way: a shipment
 * that invented an order for a scanned off-order carpet
 * (ShipmentService::createOrderLinesForScannedItems) must be able to cancel
 * that order with it, and guessing from notes text would be fragile.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('shipments', function (Blueprint $table): void {
            $table->timestamp('canceled_at')->nullable()->after('notes')->index();

            $table->foreignId('canceled_by')
                ->nullable()
                ->after('canceled_at')
                ->constrained('users')
                ->nullOnDelete();

            $table->text('cancel_reason')->nullable()->after('canceled_by');
        });

        Schema::table('orders', function (Blueprint $table): void {
            $table->foreignId('created_from_shipment_id')
                ->nullable()
                ->after('notes')
                ->constrained('shipments')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('created_from_shipment_id');
        });

        Schema::table('shipments', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('canceled_by');
            $table->dropIndex(['canceled_at']);
            $table->dropColumn(['canceled_at', 'cancel_reason']);
        });
    }
};
