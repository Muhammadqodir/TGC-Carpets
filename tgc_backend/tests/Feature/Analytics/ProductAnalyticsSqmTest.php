<?php

namespace Tests\Feature\Analytics;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductColor;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The order statistics page can switch between counting carpets and counting
 * square metres. Every quantity figure the analytics API returns has an m²
 * twin; these tests pin those down.
 */
class ProductAnalyticsSqmTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    /** 2 × 200×300 = 12 m² */
    private ProductVariant $big;

    /** 4 × 100×150 = 6 m², same product as $big */
    private ProductVariant $small;

    /** 10 units of a sizeless variant: counts as carpets, adds 0 m² */
    private ProductVariant $sizeless;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->admin()->create();

        $color          = ProductColor::factory()->create();
        $this->big      = ProductVariant::factory()->create([
            'product_color_id' => $color->id,
            'product_size_id'  => ProductSize::factory()->create(['width' => 200, 'length' => 300])->id,
        ]);
        $this->small    = ProductVariant::factory()->create([
            'product_color_id' => $color->id,
            'product_size_id'  => ProductSize::factory()->create(['width' => 100, 'length' => 150])->id,
        ]);
        $this->sizeless = ProductVariant::factory()->create();

        $order = Order::factory()->create(['user_id' => $this->admin->id]);
        foreach ([[$this->big, 2], [$this->small, 4], [$this->sizeless, 10]] as [$variant, $qty]) {
            OrderItem::create(['order_id' => $order->id, 'product_variant_id' => $variant->id, 'quantity' => $qty]);
        }

        // Canceled orders stay out of both metrics.
        $canceled = Order::factory()->create(['user_id' => $this->admin->id, 'status' => Order::STATUS_CANCELED]);
        OrderItem::create(['order_id' => $canceled->id, 'product_variant_id' => $this->big->id, 'quantity' => 100]);
    }

    public function test_report_carries_square_metres_next_to_quantities(): void
    {
        $data = $this->actingAs($this->admin)
            ->getJson('/api/v1/analytics/products?' . http_build_query($this->period()))
            ->assertOk()
            ->json('data');

        $this->assertSame(16, $data['summary']['total_items']);
        $this->assertEquals(18.0, $data['summary']['total_sqm']);
        $this->assertEquals(18.0, $data['trend'][0]['total_sqm']);

        $sizes = collect($data['by_size'])->keyBy('name');
        $this->assertEquals(12.0, $sizes['200x300']['total_sqm']);
        $this->assertEquals(66.7, $sizes['200x300']['sqm_percentage']);
        $this->assertEquals(12.5, $sizes['200x300']['percentage'], 'quantity share is unchanged: 2 of 16');
        $this->assertEquals(0.0, $sizes["O'lchamsiz"]['total_sqm']);
    }

    public function test_top_products_can_be_ranked_by_square_metres(): void
    {
        $byQty = $this->actingAs($this->admin)
            ->getJson('/api/v1/analytics/top-products?' . http_build_query($this->period()))
            ->assertOk()
            ->json('data.top_products');

        $bySqm = $this->actingAs($this->admin)
            ->getJson('/api/v1/analytics/top-products?' . http_build_query($this->period() + ['metric' => 'sqm']))
            ->assertOk()
            ->json('data.top_products');

        $sizedProduct    = $this->big->productColor->product_id;
        $sizelessProduct = $this->sizeless->productColor->product_id;

        // 10 sizeless carpets outsell 6 sized ones, but cover 0 m² against 18.
        $this->assertSame($sizelessProduct, $byQty[0]['id']);
        $this->assertSame($sizedProduct, $bySqm[0]['id']);
        $this->assertSame($sizelessProduct, $bySqm[1]['id']);
        $this->assertEquals(18.0, $bySqm[0]['total_sqm']);
        $this->assertEquals(100.0, $bySqm[0]['sqm_percentage']);

        $sizes = collect($bySqm[0]['sizes'])->keyBy('label');
        $this->assertEquals(66.7, $sizes['200x300']['sqm_percentage']);
        $this->assertEquals(33.3, $sizes['200x300']['percentage'], '2 of the product\'s 6 carpets');

    }

    public function test_unknown_metric_is_rejected(): void
    {
        $this->actingAs($this->admin)
            ->getJson('/api/v1/analytics/top-products?metric=price')
            ->assertStatus(422);
    }

    private function period(): array
    {
        return ['period_from' => now()->subDay()->toDateString(), 'period_to' => now()->toDateString()];
    }
}
