<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Adjustments were unconditionally mapped to a stock-increasing movement
 * ('adjustment' → TYPE_IN), so a stocktake shortfall — the most common
 * adjustment in practice — could never be entered. `direction` records
 * which way an adjustment actually moves stock; it is meaningless (kept
 * NULL) for every other document type, where direction is implied by
 * `type`. See instructions/phase-3/05-signed-adjustment-documents.md.
 *
 * Backfill is exact and moves no historical balance: every adjustment
 * ever written by this application added stock (the old unconditional
 * mapping), so `direction = 'in'` records what actually happened.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table): void {
            $table->enum('direction', ['in', 'out'])->nullable()->after('type');
        });

        DB::table('warehouse_documents')->where('type', 'adjustment')->update(['direction' => 'in']);
    }

    public function down(): void
    {
        Schema::table('warehouse_documents', function (Blueprint $table): void {
            $table->dropColumn('direction');
        });
    }
};
