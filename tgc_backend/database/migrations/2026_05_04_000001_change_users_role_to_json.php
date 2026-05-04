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

        // Change column type to JSON
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
    }
};
