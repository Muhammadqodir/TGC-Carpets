<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * An append-only record of who changed what on every money/stock-bearing
 * model. See instructions/phase-3/06-audit-log.md.
 *
 * Deliberate omissions, not oversights:
 * - no `updated_at` — an audit row is never updated.
 * - no FK on `user_id` — a deleted user must not block, or a cascading
 *   delete erase, the history of what they did.
 * - no FK on `auditable_id` — polymorphic, and the target may be hard-deleted
 *   (Payment, for one, still is until this ships alongside it).
 *
 * DEPLOY.md carries the REVOKE UPDATE/DELETE grant for the application DB
 * user — that is what turns "we don't write to this" into "we cannot",
 * and it has to be applied by someone with schema privileges outside a
 * migration, against the real DB user/schema names on each environment.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_log', function (Blueprint $table): void {
            $table->id();
            $table->string('auditable_type', 191);
            $table->unsignedBigInteger('auditable_id');
            $table->enum('event', ['created', 'updated', 'deleted', 'restored']);
            $table->unsignedBigInteger('user_id')->nullable();
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->uuid('request_id')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->string('url', 500)->nullable();
            $table->dateTime('created_at');

            $table->index(['auditable_type', 'auditable_id', 'created_at'], 'idx_auditable');
            $table->index(['user_id', 'created_at'], 'idx_user');
            $table->index('request_id', 'idx_request');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_log');
    }
};
