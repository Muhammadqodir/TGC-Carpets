<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('production_batches', function (Blueprint $table): void {
            $table->foreignId('responsible_employee_id')
                ->nullable()
                ->after('created_by')
                ->constrained('users')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('production_batches', function (Blueprint $table): void {
            $table->dropForeignIdFor(\App\Models\User::class, 'responsible_employee_id');
            $table->dropColumn('responsible_employee_id');
        });
    }
};
