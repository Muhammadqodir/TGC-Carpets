<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('production_events', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('production_batch_item_id')
                ->constrained('production_batch_items')
                ->cascadeOnDelete();
            $table->enum('event_type', ['produced', 'defect', 'scrap', 'correction']);
            $table->integer('quantity');            // signed: +1 label, -1 correction
            $table->dateTime('occurred_at');         // real business time; nothing else writes it
            $table->foreignId('user_id')->constrained('users');
            $table->foreignId('defect_document_id')->nullable()->constrained('defect_documents')->nullOnDelete();
            $table->char('idempotency_key', 36)->nullable()->unique('uniq_idem');
            $table->string('reason', 255)->nullable();   // required for correction/scrap
            $table->timestamp('created_at')->nullable();

            $table->index(['production_batch_item_id', 'occurred_at'], 'idx_item_time');
            $table->index('occurred_at', 'idx_time');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('production_events');
    }
};
