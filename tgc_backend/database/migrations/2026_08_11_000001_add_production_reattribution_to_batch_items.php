<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A carpet produced against one client's order can end up on another client's
 * lorry: the worker scans the label in front of them, and the shipment form
 * accepts it after a confirmation. Until now the production record stayed
 * where it was, so the client it was made for kept showing the carpet as
 * "Tayyor" (ready) long after it had physically left for someone else.
 *
 * ShipmentService now moves the produced carpet to the receiving client's
 * order line instead — see reattributeScannedProduction(). Nothing is
 * invented or destroyed: SUM(produced_quantity) across the factory is
 * unchanged, only which order line claims it, so the original client's order
 * is short again and production has to cover it.
 *
 * These two columns are what makes that reversible. A cancelled shipment must
 * put the carpet back where it came from, and neither the batch nor the order
 * records who took it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('production_batch_items', function (Blueprint $table): void {
            // The order line this row's production was taken from. Set on the
            // row that now carries it — which may be a new row created by
            // splitting, when only part of a batch item's carpets moved.
            $table->foreignId('reattributed_from_order_item_id')
                ->nullable()
                ->after('source_order_item_id')
                ->constrained('order_items')
                ->nullOnDelete();

            // Which shipment did it, so cancelling that shipment reverses
            // exactly its own moves and nobody else's. Indexed because
            // cancellation looks rows up by it.
            $table->foreignId('reattributed_by_shipment_id')
                ->nullable()
                ->after('reattributed_from_order_item_id')
                ->constrained('shipments')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('production_batch_items', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('reattributed_by_shipment_id');
            $table->dropConstrainedForeignId('reattributed_from_order_item_id');
        });
    }
};
