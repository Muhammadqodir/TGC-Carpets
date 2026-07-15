<?php

return [
    // Phase 1 step 02: flip to true only after a week of clean logs.
    // See instructions/phase-1/02-validate-shipment-items.md.
    'enforce_item_validation' => env('SHIPMENTS_ENFORCE_ITEM_VALIDATION', false),
];
