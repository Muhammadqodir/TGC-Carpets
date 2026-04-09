<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('external_uuid')->nullable()->unique();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('client_id')->nullable()->constrained()->nullOnDelete();
            $table->enum('status', ['pending', 'confirmed', 'cancelled', 'delivered'])->default('pending');
            $table->date('order_date');
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('order_date');
            $table->index('user_id');
            $table->index('client_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
