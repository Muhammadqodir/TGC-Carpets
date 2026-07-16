<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Phase 2 step 06 — nightly assertion that production_batch_items counters
// equal SUM(production_events). --fix is deliberately NOT scheduled: drift
// means something is broken, and silently papering over it nightly means
// nobody finds out. A human runs --fix after understanding the cause. See
// instructions/phase-2/06-production-reconcile-command.md.
//
// Wire onFailure() to something a human actually reads before relying on
// this — a non-zero exit code that goes nowhere is not a signal. Confirm
// cron is invoking `schedule:run` on the deploy box, or this is decoration.
Schedule::command('production:reconcile')
    ->dailyAt('02:30')
    ->onFailure(function (): void {
        Log::critical('production:reconcile — drift detected. See scheduler output / storage/logs/laravel.log.');
    });

// Phase 2 step 08 — same shape, for stock. Scheduled 15 minutes after
// production:reconcile so the two do not contend.
Schedule::command('stock:reconcile')
    ->dailyAt('02:45')
    ->onFailure(function (): void {
        Log::critical('stock:reconcile — drift detected. See scheduler output / storage/logs/laravel.log.');
    });

// Phase 3 step 02 — nightly drift report between produced_quantity and
// real ProductionUnit counts. Read-only (no --fix exists for this
// command at all during the dual-run — see the command's own docblock).
// Scheduled 10 minutes after the other two so all three do not contend.
Schedule::command('production:reconcile-units')
    ->dailyAt('02:55')
    ->onFailure(function (): void {
        Log::critical('production:reconcile-units — drift detected. See scheduler output / storage/logs/laravel.log.');
    });
