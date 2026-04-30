<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Simplify stock_movements.movement_type to only 'in' and 'out'.
 *
 * - Convert 'return' movements to 'in' (items coming back to warehouse add to stock)
 * - Convert 'adjustment' movements to 'in' (assuming adjustments are inventory corrections)
 * - Update ENUM to only allow 'in' and 'out'
 */
return new class extends Migration
{
    public function up(): void
    {
        // Convert existing 'return' movements to 'in'
        DB::statement("
            UPDATE stock_movements
            SET movement_type = 'in'
            WHERE movement_type = 'return'
        ");

        // Convert existing 'adjustment' movements to 'in'
        // Note: If adjustments should sometimes be 'out', this needs manual review
        DB::statement("
            UPDATE stock_movements
            SET movement_type = 'in'
            WHERE movement_type = 'adjustment'
        ");

        // Now alter the column to ENUM with only 'in' and 'out'
        DB::statement("
            ALTER TABLE stock_movements
            MODIFY COLUMN movement_type
                ENUM('in','out') NOT NULL
        ");
    }

    public function down(): void
    {
        // Restore the original ENUM with all 4 values
        DB::statement("
            ALTER TABLE stock_movements
            MODIFY COLUMN movement_type
                ENUM('in','out','adjustment','return') NOT NULL
        ");
    }
};
