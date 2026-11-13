<?php

namespace Tests\Feature\Labeling;

use App\Models\LabelReprint;
use App\Models\Machine;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use App\Models\ProductionUnit;
use App\Models\ProductType;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * A Kovrolin roll's real length is typed in before its label prints. It is
 * kept on the carpet and its ledger event, production m² counts it, and like
 * the carpet number it can never cost the carpet its count.
 */
class CarpetLengthTest extends TestCase
{
    use RefreshDatabase;

    private User $shift;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shift = User::factory()->labelManager()->create();
    }

    public function test_a_counted_print_keeps_its_length_on_the_carpet_and_the_event(): void
    {
        $line = $this->line(planned: 2);

        $this->print($line, 2870)
            ->assertJsonPath('counted', true)
            ->assertJsonPath('unit.length_cm', 2870);

        $this->assertSame(2870, ProductionUnit::where('production_batch_item_id', $line->id)->sole()->length_cm);
        $this->assertSame(2870, ProductionEvent::where('production_batch_item_id', $line->id)->sole()->length_cm);
    }

    public function test_a_reprint_records_its_length_without_counting(): void
    {
        $line = $this->line(planned: 1);
        $this->print($line, 3120);

        $this->print($line, 3120, reprint: true)->assertJsonPath('counted', false);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertSame(3120, LabelReprint::where('production_batch_item_id', $line->id)->sole()->length_cm);
    }

    public function test_a_nonsense_length_is_left_off_and_the_carpet_still_counts(): void
    {
        $line = $this->line(planned: 5);

        foreach (['abc', -5, 0, 28.5, 100001] as $bad) {
            $this->print($line, $bad)->assertJsonPath('counted', true);
        }

        $this->assertSame(5, $line->fresh()->produced_quantity);
        $this->assertSame([null], ProductionUnit::where('production_batch_item_id', $line->id)->pluck('length_cm')->unique()->values()->all());
    }

    public function test_an_old_app_without_lengths_keeps_working(): void
    {
        $line = $this->line(planned: 1);

        $this->print($line, null)->assertJsonPath('counted', true);

        $this->assertNull(ProductionUnit::where('production_batch_item_id', $line->id)->sole()->length_cm);
    }

    public function test_an_undo_takes_back_exactly_that_rolls_length(): void
    {
        $line = $this->line(planned: 1);
        $key  = (string) Str::uuid();
        $this->print($line, 2870, key: $key);

        $this->actingAs($this->shift, 'sanctum')
            ->postJson('/api/v1/production-batches-print-labels/undo', ['key' => $key])
            ->assertOk()
            ->assertJsonPath('status', 'undone');

        $correction = ProductionEvent::where('production_batch_item_id', $line->id)
            ->where('event_type', ProductionEvent::TYPE_CORRECTION)
            ->sole();
        $this->assertSame(-1, $correction->quantity);
        $this->assertSame(2870, $correction->length_cm);
    }

    public function test_production_m2_counts_real_lengths_and_nominal_for_the_rest(): void
    {
        config(['analytics.source' => 'events']);
        // Midday: the operations report's day starts in the morning, so a
        // run just after midnight would file these prints under yesterday.
        $this->travelTo(today()->setTime(12, 0));
        $admin = User::factory()->admin()->create();

        // 400 wide, nominal 3000 long: 120 m² a roll
        $line = $this->line(planned: 10);
        $this->print($line, 2800);   // 112 m²
        $this->print($line, 3250);   // 130 m²
        $this->print($line, null);   // 120 m², nominal

        $today = now()->toDateString();
        $report = $this->actingAs($admin, 'sanctum')
            ->getJson("/api/v1/analytics/production?period_from={$today}&period_to={$today}")
            ->assertOk()
            ->json();

        $summary = $report['data']['summary'] ?? $report['summary'];
        $this->assertSame(3, $summary['total_produced']);
        $this->assertEquals(362.0, $summary['total_sqm']);

        $ops = $this->actingAs($admin, 'sanctum')
            ->getJson("/api/v1/analytics/production/operations?period_from={$today}&period_to={$today}")
            ->assertOk()
            ->json();
        $shift = collect($ops['data']['by_shift'] ?? $ops['by_shift'])->firstWhere('name', $this->shift->name);
        $this->assertEquals(362.0, $shift['total_sqm']);
    }

    public function test_the_type_flag_reaches_the_labeling_page(): void
    {
        $line = $this->line(planned: 1);

        $this->actingAs($this->shift, 'sanctum')
            ->getJson('/api/v1/production-batches-labeling-items')
            ->assertOk()
            ->assertJsonPath('data.0.variant.product_color.product.product_type.has_variable_length', true);

        $this->assertNotNull($line);
    }

    public function test_the_migration_rolls_back_and_forward_and_flags_kovrolin(): void
    {
        $migration = require database_path('migrations/2026_11_13_000001_add_actual_length_to_printed_carpets.php');
        ProductType::create(['type' => 'Kovrolin']);

        $migration->down();
        $this->assertFalse(Schema::hasColumn('production_units', 'length_cm'));
        $this->assertFalse(Schema::hasColumn('product_types', 'has_variable_length'));

        $migration->up();
        foreach (['production_units', 'production_events', 'label_reprints'] as $table) {
            $this->assertTrue(Schema::hasColumn($table, 'length_cm'), $table);
        }
        $this->assertTrue(ProductType::where('type', 'Kovrolin')->sole()->has_variable_length);
    }

    private function line(int $planned): ProductionBatchItem
    {
        $batch = ProductionBatch::create([
            'batch_title' => 'Kovrolin partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $this->shift->id,
        ]);

        $variant = ProductVariant::factory()->create([
            'product_size_id' => ProductSize::factory()->create(['width' => 400, 'length' => 3000])->id,
        ]);
        $variant->productColor->product->productType?->update(['has_variable_length' => true]);

        return ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => $variant->id,
            'planned_quantity'    => $planned,
            'produced_quantity'   => 0,
            'defect_quantity'     => 0,
        ]);
    }

    private function print(ProductionBatchItem $line, mixed $lengthCm, bool $reprint = false, ?string $key = null): TestResponse
    {
        return $this->actingAs($this->shift, 'sanctum')
            ->postJson("/api/v1/production-batches/{$line->production_batch_id}/items/{$line->id}/print-label", array_filter([
                'idempotency_key' => $key ?? (string) Str::uuid(),
                'reprint'         => $reprint,
                'length_cm'       => $lengthCm,
            ], fn ($value) => $value !== null))
            ->assertOk();
    }
}
