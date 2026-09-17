<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A label printed for a carpet that is already counted: a replacement for a
 * label that tore or misprinted before it went on the carpet, or a print past
 * the batch line's plan. It does not add to produced_quantity, but it is still
 * a physical label someone printed, so who and when are kept here instead of
 * being lost (history reprints used to reach no server at all) or counted as a
 * carpet (a print past the plan used to raise produced_quantity).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('label_reprints', function (Blueprint $table): void {
            $table->id();

            $table->foreignId('production_batch_item_id')
                ->constrained('production_batch_items')
                ->restrictOnDelete();

            $table->foreignId('printed_by')->constrained('users');
            $table->dateTime('printed_at');

            // reprint     — the worker chose "reprint" (labeling card or print history)
            // over_target — a normal print on a line whose plan was already met
            $table->enum('reason', ['reprint', 'over_target']);

            // Same contract as production_events.idempotency_key: a retried
            // request with the same key records nothing a second time.
            $table->char('idempotency_key', 36)->nullable()->unique();

            $table->timestamps();

            $table->index(['production_batch_item_id', 'printed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('label_reprints');
    }
};
