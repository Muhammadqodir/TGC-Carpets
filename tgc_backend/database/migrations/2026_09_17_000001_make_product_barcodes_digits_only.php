<?php

use App\Models\ProductVariant;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Product barcodes become digits only ("TGC-00000042" → "2984200000429",
 * see ProductVariant::barcodeFor) because some clients' systems reject the
 * letters. Labels already on carpets keep resolving through
 * ProductVariant::idFromBarcode, so nothing needs reprinting to keep scanning.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->rewrite(fn (int $id) => ProductVariant::barcodeFor($id));
    }

    public function down(): void
    {
        $this->rewrite(fn (int $id) => sprintf('TGC-%08d', $id));
    }

    private function rewrite(callable $barcodeFor): void
    {
        DB::transaction(function () use ($barcodeFor): void {
            DB::table('product_variants')->select('id')->orderBy('id')
                ->chunkById(500, function ($variants) use ($barcodeFor): void {
                    foreach ($variants as $variant) {
                        DB::table('product_variants')
                            ->where('id', $variant->id)
                            ->update(['barcode_value' => $barcodeFor((int) $variant->id)]);
                    }
                });
        });
    }
};
