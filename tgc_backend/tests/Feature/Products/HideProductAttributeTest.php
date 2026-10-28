<?php

namespace Tests\Feature\Products;

use App\Models\Color;
use App\Models\Product;
use App\Models\ProductColor;
use App\Models\ProductEdge;
use App\Models\ProductQuality;
use App\Models\ProductSize;
use App\Models\ProductType;
use App\Models\ProductVariant;
use App\Models\User;
use App\Services\ProductVariantService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Deleting an attribute that products still use used to demand a
 * replacement. `mode=hide` instead soft-deletes it: gone from the pickers,
 * untouched on everything that already uses it.
 */
class HideProductAttributeTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = User::factory()->admin()->create();
    }

    public function test_hiding_a_used_type_leaves_its_products_alone(): void
    {
        $type    = ProductType::factory()->create(['type' => 'Gilam']);
        $product = Product::factory()->create(['product_type_id' => $type->id]);

        $this->actingAs($this->admin)
            ->deleteJson("/api/v1/product-types/{$type->id}", ['mode' => 'hide'])
            ->assertOk();

        $this->assertSoftDeleted($type);
        $this->assertSame($type->id, $product->fresh()->product_type_id);
        $this->assertSame('Gilam', $product->fresh()->productType->type, 'still shown on the product');

        $listed = collect($this->getJson('/api/v1/product-types')->assertOk()->json('data'))->pluck('id');
        $this->assertNotContains($type->id, $listed, 'gone from the picker');
    }

    public function test_every_attribute_can_be_hidden_while_in_use(): void
    {
        $variant = ProductVariant::factory()->create([
            'product_size_id' => ProductSize::factory()->create()->id,
            'product_edge_id' => ProductEdge::factory()->create()->id,
        ]);
        $product = $variant->productColor->product;

        $targets = [
            'product-qualities' => $product->productQuality,
            'colors'            => $variant->productColor->color,
            'product-sizes'     => $variant->productSize,
            'product-edges'     => $variant->productEdge,
        ];

        foreach ($targets as $route => $model) {
            $this->actingAs($this->admin)
                ->deleteJson("/api/v1/{$route}/{$model->id}", ['mode' => 'hide'])
                ->assertOk();
            $this->assertSoftDeleted($model);
        }

        $variant = ProductVariant::with(['productSize', 'productEdge', 'productColor.color', 'productColor.product.productQuality'])
            ->find($variant->id);
        $this->assertNotNull($variant->productSize);
        $this->assertNotNull($variant->productEdge);
        $this->assertNotNull($variant->productColor->color);
        $this->assertNotNull($variant->productColor->product->productQuality);
    }

    public function test_orders_can_still_resolve_a_variant_with_a_hidden_size_and_edge(): void
    {
        $pc   = ProductColor::factory()->create();
        $size = ProductSize::factory()->create();
        $edge = ProductEdge::factory()->create();
        $size->delete();
        $edge->delete();

        // A new colour line on an old order still needs a variant minted.
        $variant = app(ProductVariantService::class)->findOrCreate($pc->id, $size->id, $edge->id);

        $this->assertSame($size->id, $variant->product_size_id);
        $this->assertSame($edge->id, $variant->product_edge_id);
    }

    public function test_adding_a_hidden_name_again_restores_the_same_row(): void
    {
        $color = Color::factory()->create(['name' => 'Qizil']);
        $color->delete();

        $this->actingAs($this->admin)->postJson('/api/v1/colors', ['name' => 'Qizil'])
            ->assertOk()
            ->assertJsonPath('data.id', $color->id);
        $this->assertNotSoftDeleted($color);

        $type = ProductType::factory()->create(['type' => 'Yolak']);
        $type->delete();
        $this->actingAs($this->admin)->postJson('/api/v1/product-types', ['type' => 'Yolak'])
            ->assertOk()
            ->assertJsonPath('data.id', $type->id);

        $size = ProductSize::factory()->create(['width' => 100, 'length' => 200]);
        $size->delete();
        $this->actingAs($this->admin)->postJson('/api/v1/product-sizes', [
            'width' => 100, 'length' => 200, 'product_type_id' => $size->product_type_id,
        ])->assertOk()->assertJsonPath('data.id', $size->id);

        $quality = ProductQuality::factory()->create(['quality_name' => 'Lux']);
        $quality->delete();
        $this->actingAs($this->admin)->postJson('/api/v1/product-qualities', ['quality_name' => 'Lux'])
            ->assertOk()
            ->assertJsonPath('data.id', $quality->id);

        $edge = ProductEdge::factory()->create(['code' => 'Z', 'title' => 'Zigzag']);
        $edge->delete();
        $this->actingAs($this->admin)->postJson('/api/v1/product-edges', ['code' => 'Z', 'title' => 'Zigzag'])
            ->assertOk()
            ->assertJsonPath('data.id', $edge->id);
    }

    public function test_without_hide_mode_a_used_type_still_needs_a_replacement(): void
    {
        $type = ProductType::factory()->create();
        Product::factory()->create(['product_type_id' => $type->id]);

        // What app versions without the hide button send.
        $this->actingAs($this->admin)
            ->deleteJson("/api/v1/product-types/{$type->id}")
            ->assertStatus(422);
    }

    public function test_plain_delete_of_an_unused_attribute_is_still_permanent(): void
    {
        $quality = ProductQuality::factory()->create();

        $this->actingAs($this->admin)
            ->deleteJson("/api/v1/product-qualities/{$quality->id}")
            ->assertOk();

        $this->assertNull(ProductQuality::withTrashed()->find($quality->id));
    }
}
