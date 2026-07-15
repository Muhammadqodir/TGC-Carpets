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
];
