<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * The forensic trail for phase-1 step 05's variant merge. Additive, empty
 * until `variants:merge-duplicates --force` is run — safe to deploy on its
 * own ahead of the merge itself. Keep this table forever: it is the only
 * record of what a merged-away variant used to be, and a mis-merge may not
 * be noticed for weeks. See
 * instructions/phase-1/05-variant-unique-constraint.md "Stage 3".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_variant_merges', function (Blueprint $table): void {
            $table->id();
            $table->unsignedBigInteger('loser_variant_id');     // deleted
            $table->unsignedBigInteger('survivor_variant_id');  // kept
            $table->json('loser_snapshot');                     // full row before deletion
            $table->json('repointed_counts');                   // {stock_movements: 12, order_items: 3, ...}
            $table->string('reason');                           // who decided, and why
            $table->timestamps();

            $table->index('loser_variant_id');
            $table->index('survivor_variant_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variant_merges');
    }
};
