<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shipments', function (Blueprint $table) {
            $table->id();

            $table->foreignId('client_id')
                ->constrained('clients')
                ->restrictOnDelete();

            $table->foreignId('user_id')
                ->constrained('users')
                ->restrictOnDelete();

            $table->foreignId('order_id')
                ->nullable()
                ->constrained('orders')
                ->nullOnDelete();

            $table->timestamp('shipment_datetime');
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('client_id');
            $table->index('order_id');
            $table->index('shipment_datetime');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shipments');
    }
};
