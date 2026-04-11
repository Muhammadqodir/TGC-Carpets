<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('production_batch_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('production_batch_id')->constrained('production_batches')->cascadeOnDelete();
            $table->enum('source_type', ['order_item', 'stock_request', 'manual'])->default('manual');
            $table->foreignId('source_order_item_id')->nullable()->constrained('order_items')->nullOnDelete();
            $table->foreignId('product_variant_id')->constrained('product_variants')->restrictOnDelete();
            $table->unsignedInteger('planned_quantity');
            $table->unsignedInteger('produced_quantity')->default(0);
            $table->unsignedInteger('defect_quantity')->default(0);
            $table->unsignedInteger('warehouse_received_quantity')->default(0);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('production_batch_id');
            $table->index('source_order_item_id');
            $table->index('product_variant_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('production_batch_items');
    }
};
