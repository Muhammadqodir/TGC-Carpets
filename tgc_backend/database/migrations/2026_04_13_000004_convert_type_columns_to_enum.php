<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Convert warehouse_documents.type and stock_movements.movement_type
 * from VARCHAR to ENUM for database-level constraint enforcement.
 *
 * Uses raw ALTER TABLE to avoid doctrine/dbal dependency.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("
            ALTER TABLE warehouse_documents
            MODIFY COLUMN type
                ENUM('in','out','adjustment','return') NOT NULL
        ");

        DB::statement("
            ALTER TABLE stock_movements
            MODIFY COLUMN movement_type
                ENUM('in','out','adjustment','return') NOT NULL
        ");
    }

    public function down(): void
    {
        DB::statement("
            ALTER TABLE warehouse_documents
            MODIFY COLUMN type VARCHAR(255) NOT NULL
        ");

        DB::statement("
            ALTER TABLE stock_movements
            MODIFY COLUMN movement_type VARCHAR(255) NOT NULL
        ");
    }
};
