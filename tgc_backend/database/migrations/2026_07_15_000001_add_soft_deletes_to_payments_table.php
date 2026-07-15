<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table): void {
            $table->softDeletes();          // deleted_at TIMESTAMP NULL — additive, nullable, safe live
            $table->index('deleted_at');    // every query now filters on it
        });
    }

    public function down(): void
    {
        // Prefer leaving deleted_at in place — dropping it destroys the record
        // of every soft-delete made while this was live. See
        // instructions/phase-1/06-payment-soft-deletes.md "Rollback".
        Schema::table('payments', function (Blueprint $table): void {
            $table->dropIndex(['deleted_at']);
            $table->dropSoftDeletes();
        });
    }
};
