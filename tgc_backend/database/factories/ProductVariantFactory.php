<?php

namespace Database\Factories;

use App\Models\ProductColor;
use App\Models\ProductVariant;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<ProductVariant>
 */
class ProductVariantFactory extends Factory
{
    protected $model = ProductVariant::class;

    public function definition(): array
    {
        return [
            'product_color_id' => ProductColor::factory(),
            'product_size_id'  => null,
            'product_edge_id'  => null,
            'sku_code'         => 'TGC-TEST-' . Str::upper(Str::random(8)),
        ];
    }

    /**
     * Set barcode_value after creation the same way the app does (embeds the ID).
     */
    public function configure(): static
    {
        return $this->afterCreating(function (ProductVariant $variant): void {
            if (empty($variant->barcode_value)) {
                $variant->update(['barcode_value' => sprintf('TGC-VAR-%08d', $variant->id)]);
            }
        });
    }
}
