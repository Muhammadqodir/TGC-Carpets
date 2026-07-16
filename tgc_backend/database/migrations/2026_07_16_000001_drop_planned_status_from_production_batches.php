<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * production_batches.status was created as
 * ENUM('planned','in_progress','completed','cancelled'), but
 * ProductionBatchService::create() has always forced status to
 * 'in_progress' on insert — the column default was never reached by any
 * write path. No batch has ever been 'planned', which made
 * ProductionBatchController::start() and the old destroy() guard
 * (`status !== 'planned'`) unreachable code: start() could never fire and
 * destroy() rejected every batch that has ever existed.
 *
 * Path B, per instructions/phase-3/03-fix-batch-state-machine.md: remove
 * the unused state rather than build out scheduling. destroy() now allows
 * deletion of any non-completed batch that has recorded no production
 * (ProductionBatchService::assertNoRecordedProduction()), which is the
 * real, reachable rule this migration unblocks.
 *
 * Safe because no row can be affected — verified by the COUNT(*) guard
 * below, which aborts rather than silently truncating data if that
 * assumption is ever wrong on a given environment.
 */
return new class extends Migration
{
    public function up(): void
    {
        $planned = DB::table('production_batches')->where('status', 'planned')->count();

        if ($planned > 0) {
            throw new \RuntimeException(
                "Refusing to drop 'planned' from production_batches.status: "
                . "{$planned} row(s) currently have that status. This should be "
                . "impossible (create() always forces in_progress) — investigate "
                . "before proceeding. See instructions/phase-3/03-fix-batch-state-machine.md."
            );
        }

        DB::statement("
            ALTER TABLE production_batches
            MODIFY COLUMN status
                ENUM('in_progress','completed','cancelled') NOT NULL DEFAULT 'in_progress'
        ");
    }

    public function down(): void
    {
        DB::statement("
            ALTER TABLE production_batches
            MODIFY COLUMN status
                ENUM('planned','in_progress','completed','cancelled') NOT NULL DEFAULT 'planned'
        ");
    }
};
