<?php

use App\Models\ProductVariant;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Product barcodes become an 8-digit EAN-8 ("2984200059847" → "50059843",
 * see ProductVariant::barcodeFor) so the label's barcode is half as wide and
 * a PDA aimed at the 21 carpet number does not read it instead. Labels and
 * client records with the 13-digit code keep resolving through
 * ProductVariant::idFromBarcode.
 */
return new class extends Migration
{
    public function up(): void
    {
        $this->rewrite(fn (int $id) => ProductVariant::barcodeFor($id));
    }

    public function down(): void
    {
        $this->rewrite(fn (int $id) => ProductVariant::legacyBarcodeFor($id));
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
