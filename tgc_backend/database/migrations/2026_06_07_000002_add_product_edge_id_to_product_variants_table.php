<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Ensure the 'R' edge exists before backfilling
        $edgeId = DB::table('product_edges')->where('code', 'R')->value('id');

        if (! $edgeId) {
            $edgeId = DB::table('product_edges')->insertGetId([
                'code'       => 'R',
                'title'      => 'Tortburchak',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        Schema::table('product_variants', function (Blueprint $table) {
            $table->foreignId('product_edge_id')
                ->nullable()
                ->after('product_size_id')
                ->constrained('product_edges')
                ->restrictOnDelete();
        });

        // Backfill all existing variants with the 'R' edge
        DB::table('product_variants')->whereNull('product_edge_id')->update(['product_edge_id' => $edgeId]);
    }

    public function down(): void
    {
        Schema::table('product_variants', function (Blueprint $table) {
            $table->dropForeign(['product_edge_id']);
            $table->dropColumn('product_edge_id');
        });
    }
};
