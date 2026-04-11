<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('production_batches', function (Blueprint $table): void {
            $table->id();
            $table->string('batch_title');
            $table->dateTime('planned_datetime')->nullable();
            $table->dateTime('started_datetime')->nullable();
            $table->dateTime('completed_datetime')->nullable();
            $table->foreignId('machine_id')->constrained('machines')->restrictOnDelete();
            $table->enum('type', ['by_order', 'for_stock', 'mixed'])->default('by_order');
            $table->enum('status', ['planned', 'in_progress', 'completed', 'cancelled'])->default('planned');
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('status');
            $table->index('type');
            $table->index('machine_id');
            $table->index('planned_datetime');
            $table->index('created_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('production_batches');
    }
};
