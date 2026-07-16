<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Base currency
    |--------------------------------------------------------------------------
    |
    | Every cross-currency aggregate (client debit totals, dashboards)
    | converts to this using each row's own stored, frozen exchange_rate —
    | never a rate looked up at read time. See
    | instructions/phase-3/04-currency-vat-discount.md.
    |
    */
    'base_currency' => 'USD',

    /*
    |--------------------------------------------------------------------------
    | Rounding
    |--------------------------------------------------------------------------
    |
    | Half-up (round-half-away-from-zero), matching ShipmentItem::round2()
    | and ClientDebitService's MySQL ROUND(). Not currently swappable — a
    | second mode would need every call site updated in lockstep. Recorded
    | here as documentation of the decision, not as live config.
    |
    */
    'rounding_mode' => 'half_up',

    /*
    |--------------------------------------------------------------------------
    | VAT applies to the discounted subtotal
    |--------------------------------------------------------------------------
    |
    | i.e. subtotal = SUM(line net, post-discount), vat_amount =
    | round(subtotal * vat_rate, 2). This is an Uzbek tax-law question, not
    | an engineering one — confirm with whoever files a hisob-faktura
    | before enabling a non-zero vat_rate in production, and update this
    | comment with the date it was confirmed.
    |
    | Unconfirmed as of 2026-07-16 — vat_rate defaults to 0 everywhere
    | until someone who has actually filed a hisob-faktura signs off.
    |
    */
    'vat_applies_to' => 'discounted_subtotal',

];
