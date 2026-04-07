<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * product_variants represents a unique (product, size) combination.
     *
     * The barcode_value is generated lazily after the record is first inserted
     * so it can embed the auto-increment ID.
     *
     * NOTE: MySQL does not enforce uniqueness on composite NULL columns, so
     * the application service uses a transaction + SELECT FOR UPDATE to
     * prevent duplicate (product_id, NULL) rows at the code level.
     */
    public function up(): void
    {
        Schema::create('product_variants', function (Blueprint $table) {
            $table->id();

            $table->foreignId('product_id')
                ->constrained('products')
                ->restrictOnDelete();

            $table->foreignId('product_size_id')
                ->nullable()
                ->constrained('product_sizes')
                ->restrictOnDelete();

            // Generated lazily:  "TGC-VAR-00000001"
            $table->string('barcode_value', 50)->nullable()->unique();

            $table->timestamps();

            // Covers non-NULL size combinations efficiently.
            // NULL-size uniqueness is enforced by the service layer.
            $table->index(['product_id', 'product_size_id'], 'variants_product_size_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('product_variants');
    }
};
