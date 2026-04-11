<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('defect_documents', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('production_batch_id')
                  ->constrained('production_batches')
                  ->cascadeOnDelete();
            $table->foreignId('user_id')
                  ->constrained('users');
            $table->timestamp('datetime')->useCurrent();
            $table->text('description');
            $table->timestamps();

            $table->index('production_batch_id');
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('defect_documents');
    }
};
