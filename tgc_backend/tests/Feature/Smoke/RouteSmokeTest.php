<?php

namespace Tests\Feature\Smoke;

use App\Models\Client;
use App\Models\Color;
use App\Models\Machine;
use App\Models\Product;
use App\Models\ProductColor;
use App\Models\ProductEdge;
use App\Models\ProductQuality;
use App\Models\ProductSize;
use App\Models\ProductType;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Hits every API route with id-parameters substituted with 1 and asserts it
 * is not a 5xx. A 2xx/4xx means the code ran; a 5xx means it did not compile
 * or blew up on a code path nothing has ever exercised.
 *
 * This is the test that would have caught every "endpoint completely dead"
 * bug found in phase-0 (dashboard 500, warehouse update 100% failure) and
 * phase-3 (QR scan format never matching any label the client prints).
 * See instructions/phase-3/01-tests-and-ci.md.
 */
class RouteSmokeTest extends TestCase
{
    use RefreshDatabase;

    public static function routeProvider(): array
    {
        return collect(Route::getRoutes())
            ->filter(fn ($r) => str_starts_with($r->uri(), 'api/'))
            ->flatMap(fn ($r) => collect($r->methods())
                ->reject(fn ($m) => in_array($m, ['HEAD', 'OPTIONS'], true))
                ->map(fn ($m) => [$m, $r->uri(), $r->getName()]))
            ->values()
            ->mapWithKeys(fn ($x) => ["{$x[0]} {$x[1]}" => $x])
            ->all();
    }

    #[DataProvider('routeProvider')]
    public function test_route_does_not_500(string $method, string $uri, ?string $name): void
    {
        $this->seedMinimalFixtures();

        $user = User::factory()->admin()->create();
        $url  = '/' . preg_replace('/\{[^}]+\}/', '1', $uri);

        $response = $this->actingAs($user, 'sanctum')->json($method, $url);

        $this->assertLessThan(
            500,
            $response->status(),
            "{$method} {$uri} ({$name}) returned {$response->status()}: " . $response->getContent()
        );
    }

    /**
     * One row per lookup table so {id} = 1 route-model-binding reaches real
     * logic instead of 404ing before it. Upgrades this from "does it
     * compile" to "does the happy path run".
     */
    private function seedMinimalFixtures(): void
    {
        $type    = ProductType::factory()->create();
        $quality = ProductQuality::factory()->create();
        $color   = Color::factory()->create();
        $edge    = ProductEdge::factory()->create(['code' => 'R']);
        $size    = ProductSize::factory()->create(['product_type_id' => $type->id]);

        $product = Product::factory()->create([
            'product_type_id'    => $type->id,
            'product_quality_id' => $quality->id,
        ]);

        $productColor = ProductColor::factory()->create([
            'product_id' => $product->id,
            'color_id'   => $color->id,
        ]);

        ProductVariant::factory()->create([
            'product_color_id' => $productColor->id,
            'product_size_id'  => $size->id,
            'product_edge_id'  => $edge->id,
        ]);

        Client::factory()->create();
        Machine::factory()->create();
    }
}
