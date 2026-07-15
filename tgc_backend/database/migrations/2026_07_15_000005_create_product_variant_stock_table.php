<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('product_variant_stock', function (Blueprint $table): void {
            // product_variant_id is the PRIMARY KEY — exactly one balance row
            // per variant. Also makes the lock target the primary key.
            $table->foreignId('product_variant_id')
                ->primary()
                ->constrained('product_variants')
                ->cascadeOnDelete();
            // Signed, not unsignedInteger — production_batch_items' unsigned
            // columns were a trap (see phase-2 step 05). If stock is already
            // negative on live (the race this table exists to fix), the
            // schema must be able to represent that rather than hide it.
            $table->integer('quantity')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variant_stock');
    }
};
