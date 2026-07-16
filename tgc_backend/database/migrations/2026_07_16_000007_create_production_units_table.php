<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One row per physical carpet. Today's unit of record is the batch
 * *line*, and quantity is a bare integer on it — so all N carpets cut
 * from one line carry a byte-identical QR code and cannot be told apart.
 * See instructions/phase-3/02-production-units-serials.md.
 *
 * Purely additive — nothing reads this table yet. produced_quantity on
 * production_batch_items stays the counter of record until the
 * reconciliation window (production:reconcile-units) has been clean for
 * two weeks; see that step's own docblock.
 *
 * Correction to the original brief: unlike when this instruction file was
 * written, the QR scan endpoint is NOT currently dead — phase-0 already
 * fixed ProductionBatchController::scanItem() to accept both
 * `P{batchId} I{itemId}` and `PB{batchId} PBI{itemId}`, and both formats
 * are in active use by the client. This table's serial format
 * (`TGC-U-\d{8}`) is added ALONGSIDE that, not as a replacement — see
 * the scan endpoint changes for how both are resolved.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('production_units', function (Blueprint $table): void {
            $table->id();

            $table->foreignId('production_batch_item_id')
                ->constrained('production_batch_items')
                ->restrictOnDelete();

            // TGC-U-00001234 — goes in the QR. CHAR(14) fits TGC-U- + 8
            // digits exactly, consistent with the client's existing
            // TGC-VAR-%08d / TGC-%08d barcode shapes.
            $table->char('serial', 14)->unique();

            $table->foreignId('printed_by')->constrained('users');
            $table->dateTime('printed_at');

            $table->enum('status', ['good', 'defect', 'scrapped', 'received', 'shipped'])
                ->default('good');

            $table->foreignId('warehouse_document_item_id')
                ->nullable()
                ->constrained('warehouse_document_items')
                ->nullOnDelete();

            $table->foreignId('shipment_item_id')
                ->nullable()
                ->constrained('shipment_items')
                ->nullOnDelete();

            // Reprints are the fact this table exists to make visible —
            // count them instead of discarding them.
            $table->unsignedInteger('reprint_count')->default(0);

            // Set only by the one-shot backfill command
            // (production:backfill-units). A backfilled row does NOT
            // correspond to any physical label — the carpet it represents
            // was labelled before this table existed, with the old
            // batch-line QR, which is still perfectly scannable (see
            // above). This column is what lets a later query tell real
            // units apart from synthetic ones; never treat a backfilled
            // row as traceable.
            $table->dateTime('backfilled_at')->nullable();

            $table->timestamps();

            $table->index(['production_batch_item_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('production_units');
    }
};
