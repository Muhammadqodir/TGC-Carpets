<?php

return [
    // Phase 2 step 04: which source production analytics reads from.
    //   'legacy' — production_batch_items.updated_at (wrong; dates output by
    //              whatever last touched the row, not when it was made)
    //   'events' — production_events.occurred_at (correct)
    // Flip only after showing the owner the /analytics/production/compare
    // delta and getting his sign-off — see
    // instructions/phase-2/04-repoint-analytics-to-occurred-at.md "Rollout".
    'source' => env('ANALYTICS_SOURCE', 'legacy'),

    // Hour (local time, 0-23) a production day starts at, for the shift and
    // machine report. A night shift that runs past midnight is one working
    // day, not two halves. 0 = calendar days. The shifts change at 07:00.
    'production_day_start_hour' => (int) env('PRODUCTION_DAY_START_HOUR', 7),
];
