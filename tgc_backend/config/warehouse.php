<?php

return [
    // Phase 1 step 07: flip to true only after running the reconciliation
    // queries in instructions/phase-0/reconcile-before-deploy.sql (and its
    // phase-1 additions) against production and confirming the allocation
    // mismatch is rare, not routine. See
    // instructions/phase-1/07-symmetric-fifo-allocation.md "Rollback".
    'enforce_allocation_check' => env('WAREHOUSE_ENFORCE_ALLOCATION_CHECK', false),
];
