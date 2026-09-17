<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // First, migrate existing data to JSON format
        DB::statement("UPDATE users SET role = JSON_ARRAY(role) WHERE role IS NOT NULL");

        // Change column type to JSON. MySQL 8+ refuses a plain index on a
        // JSON column (error 3152), so the index from the add_role migration
        // goes first. MariaDB, which production runs, accepted it as-is — this
        // migration ran there long before the guard existed, so the guard only
        // matters for fresh databases like the test suite's.
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasIndex('users', ['role'])) {
                $table->dropIndex(['role']);
            }
        });

        Schema::table('users', function (Blueprint $table) {
            $table->json('role')->change();
        });
    }

    public function down(): void
    {
        // Extract first role from JSON array back to string
        DB::statement("UPDATE users SET role = JSON_UNQUOTE(JSON_EXTRACT(role, '$[0]'))");

        Schema::table('users', function (Blueprint $table) {
            $table->string('role')->default('seller')->change();
        });

        // Restores what up() dropped, so the add_role migration's own down()
        // still finds the index it expects to remove.
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasIndex('users', ['role'])) {
                $table->index('role');
            }
        });
    }
};
