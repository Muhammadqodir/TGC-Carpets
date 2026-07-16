<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A reservation is a claim by one order line on a quantity of a variant.
 * It is NOT a stock_movement — reserving a carpet moves nothing, the
 * carpet does not change location. `physical` (stock_movements) and
 * `reserved` (this table, status='active') are two different sums that
 * combine into `available = physical - reserved`, which may be negative
 * (a real backorder, not an error — see instructions/phase-3/07-stock-reservations.md).
 *
 * Ships in warn-only mode: nothing in this pass blocks an order or a
 * shipment on this table's numbers. It exists to make `available` visible
 * for the first time.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stock_reservations', function (Blueprint $table): void {
            $table->id();

            $table->foreignId('product_variant_id')->constrained('product_variants');
            $table->foreignId('order_item_id')->constrained('order_items')->cascadeOnDelete();

            $table->unsignedInteger('quantity');
            $table->enum('status', ['active', 'fulfilled', 'released', 'expired'])->default('active');

            $table->foreignId('reserved_by')->constrained('users');
            $table->dateTime('reserved_at');
            $table->dateTime('released_at')->nullable();
            $table->string('release_reason')->nullable();
            $table->dateTime('expires_at')->nullable();

            $table->timestamps();

            $table->index(['product_variant_id', 'status'], 'idx_variant_status');
            $table->index('order_item_id', 'idx_order_item');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stock_reservations');
    }
};
