<?php

return [
    // Phase 1 step 08: flip to true only after a week of clean logs, or
    // immediately if the pre-deploy negative-balance query returns zero rows.
    // See instructions/phase-1/08-raw-material-validation-decimal.md.
    'enforce_stock_validation' => env('RAW_MATERIALS_ENFORCE_STOCK_VALIDATION', false),
];
