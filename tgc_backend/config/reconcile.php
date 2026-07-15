<?php

return [
    // Phase 2 steps 06/08: the users.id attributed to correction/adjustment
    // events written by `--fix`. Must be a real row in `users` (the FK on
    // production_events.user_id is NOT NULL) — set this before ever running
    // `production:reconcile --fix`. Left unset (null) is deliberate: it
    // forces whoever runs --fix for the first time to make an explicit
    // choice rather than silently attributing corrections to user #1.
    'system_user_id' => env('RECONCILE_SYSTEM_USER_ID'),
];
