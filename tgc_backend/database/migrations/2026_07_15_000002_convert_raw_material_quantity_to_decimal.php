<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * DOUBLE -> DECIMAL(12,3). Exact base-10 arithmetic for a column whose whole
 * purpose is to be summed; kg/sqm/meter quantities drift under binary float.
 *
 * DO NOT let this run bundled with the rest of phase-1 via a blind
 * `php artisan migrate --force`. See instructions/phase-1/08 and this
 * repo's instructions/phase-1/DEPLOY.md "Step 08's decimal migration" —
 * run the pre-flight drift queries first, and mind that this ALTER
 * rewrites every row (a lock window on a large table).
 *
 * Raw `DB::statement` ALTER, not $table->decimal(...)->change() — Laravel's
 * change() needs doctrine/dbal, which is not in composer.json's require
 * block. The rest of this codebase already uses raw ALTER for type changes
 * (2026_04_07_000006, 2026_04_07_000007).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'ALTER TABLE raw_material_stock_movements MODIFY quantity DECIMAL(12,3) NOT NULL'
        );
    }

    public function down(): void
    {
        // The 3dp rounding this ALTER performs is not undone by reverting the
        // column type — values rounded on the way in stay rounded. This is
        // effectively one-way; see instructions/phase-1/08 "Rollback".
        DB::statement('ALTER TABLE raw_material_stock_movements MODIFY quantity DOUBLE NOT NULL');
    }
};
