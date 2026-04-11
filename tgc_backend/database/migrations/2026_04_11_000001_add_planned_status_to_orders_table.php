<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // MySQL: modify the ENUM to include the new 'planned' value.
        DB::statement("ALTER TABLE orders MODIFY COLUMN status ENUM('pending','planned','on_production','done','canceled') NOT NULL DEFAULT 'pending'");
    }

    public function down(): void
    {
        // Revert to original ENUM (rows with 'planned' will need to be updated first).
        DB::statement("UPDATE orders SET status = 'pending' WHERE status = 'planned'");
        DB::statement("ALTER TABLE orders MODIFY COLUMN status ENUM('pending','on_production','done','canceled') NOT NULL DEFAULT 'pending'");
    }
};
