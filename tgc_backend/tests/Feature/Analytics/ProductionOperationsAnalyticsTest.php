<?php

namespace Tests\Feature\Analytics;

use App\Models\LabelReprint;
use App\Models\Machine;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Two shifts on two looms over two production days. Day 1 starts at 08:00
 * on the 1st; the night shift's 02:00 prints on the 2nd still belong to it.
 */
class ProductionOperationsAnalyticsTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $day;

    private User $night;

    private Machine $loomA;

    private Machine $loomB;

    private Machine $idle;

    protected function setUp(): void
    {
        parent::setUp();
        config(['analytics.production_day_start_hour' => 8]);

        $this->admin = User::factory()->admin()->create();
        $this->day   = User::factory()->labelManager()->create(['name' => '1 SMENA (YORLIQ)']);
        $this->night = User::factory()->labelManager()->create(['name' => '2 SMENA (YORLIQ)']);
        $this->loomA = Machine::factory()->create(['name' => 'A']);
        $this->loomB = Machine::factory()->create(['name' => 'B']);
        $this->idle  = Machine::factory()->create(['name' => 'C']);

        // 200×300 = 6 m² each
        $lineA = $this->line($this->loomA);
        $lineB = $this->line($this->loomB);

        // Production day 2026-10-01
        $this->produced($lineA, $this->day, '2026-10-01 09:15', 3);
        $this->produced($lineA, $this->night, '2026-10-01 21:00', 1);
        $this->produced($lineB, $this->night, '2026-10-02 02:30', 2);   // still day 1
        // Production day 2026-10-02
        $this->produced($lineA, $this->day, '2026-10-02 10:00', 1);

        // A pre-July lump: out of every figure, but reported.
        $this->event($lineA, $this->admin, '2026-10-02 12:00', ProductionEvent::TYPE_PRODUCED, 50, 'backfill');
        // An admin's correction: lowers machine output, not a shift's.
        $this->event($lineA, $this->admin, '2026-10-01 12:30', ProductionEvent::TYPE_CORRECTION, -1, 'over-target');
        $this->event($lineB, $this->admin, '2026-10-02 13:00', ProductionEvent::TYPE_DEFECT, 2);

        LabelReprint::create([
            'production_batch_item_id' => $lineB->id,
            'printed_by'               => $this->night->id,
            'printed_at'               => '2026-10-02 03:00',
            'reason'                   => LabelReprint::REASON_REPRINT,
        ]);

        // Outside the period (production day 2026-09-30)
        $this->produced($lineA, $this->night, '2026-10-01 07:59', 9);
    }

    public function test_shifts_are_the_accounts_that_printed_with_their_own_best_day(): void
    {
        $shifts = collect($this->report()['by_shift'])->keyBy('name');

        $day = $shifts['1 SMENA (YORLIQ)'];
        $this->assertSame(4, $day['total_quantity']);
        $this->assertEquals(24.0, $day['total_sqm']);
        $this->assertSame(2, $day['working_days']);
        $this->assertSame(3, $day['best_day_quantity']);
        $this->assertSame('2026-10-01', $day['best_day_quantity_date']);
        $this->assertEquals(66.7, $day['utilization_quantity'], 'avg 2/day against a best of 3');

        $night = $shifts['2 SMENA (YORLIQ)'];
        $this->assertSame(3, $night['total_quantity']);
        $this->assertSame(1, $night['working_days'], 'a shift across midnight is one working day');
        $this->assertEquals(100.0, $night['utilization_quantity']);
        $this->assertSame(1, $night['reprints']);

        // The admin printed nothing; they show up only for what they recorded.
        $admin = $shifts[$this->admin->name];
        $this->assertSame(0, $admin['total_quantity']);
        $this->assertSame(2, $admin['total_defects']);
        $this->assertNull($admin['utilization_quantity']);
    }

    public function test_machines_net_corrections_and_list_idle_looms(): void
    {
        $machines = collect($this->report()['by_machine'])->keyBy('name');

        $this->assertSame(4, $machines['A']['total_quantity'], '3 + 1 + 1, minus the correction');
        $this->assertSame(2, $machines['B']['total_quantity']);
        $this->assertSame(2, $machines['B']['total_defects']);
        $this->assertEquals(50.0, $machines['B']['defect_rate']);
        $this->assertSame(1, $machines['B']['reprints']);
        $this->assertSame(0, $machines['C']['total_quantity']);
        $this->assertSame(0, $machines['C']['working_days']);
    }

    public function test_summary_and_heatmap(): void
    {
        $data = $this->report();

        $this->assertSame(8, $data['day_start_hour']);
        $this->assertSame(6, $data['summary']['total_quantity']);
        $this->assertSame(2, $data['summary']['working_days']);
        $this->assertSame(5, $data['summary']['best_day_quantity'], '6 printed minus the correction');
        $this->assertSame('2026-10-01', $data['summary']['best_day_quantity_date']);
        $this->assertSame(50, $data['summary']['backfilled_excluded']);
        $this->assertSame(1, $data['summary']['reprints']);

        // Heatmap is on the real clock: Friday 2026-10-02, 02:00.
        $cell = collect($data['heatmap'])->first(fn ($c) => $c['hour'] === 2);
        $this->assertSame(4, $cell['weekday']);
        $this->assertSame($this->night->id, $cell['user_id']);
        $this->assertSame(2, $cell['total_quantity']);
        $this->assertSame(7, collect($data['heatmap'])->sum('total_quantity'), 'produced events only');
    }

    public function test_trend_splits_each_production_day_by_shift(): void
    {
        $trend = collect($this->report()['trend'])
            ->mapWithKeys(fn ($r) => [$r['label'] . '/' . $r['user_id'] => $r['total_quantity']]);

        $this->assertEquals([
            '2026-10-01/' . $this->day->id   => 3,
            '2026-10-01/' . $this->night->id => 3,   // 21:00 and the 02:30 after midnight
            '2026-10-02/' . $this->day->id   => 1,
        ], $trend->all());

        $monthly = $this->report('&trend_by=month')['trend'];
        $this->assertSame(['2026-10', '2026-10'], array_column($monthly, 'label'));
    }

    private function report(string $extra = ''): array
    {
        return $this->actingAs($this->admin)
            ->getJson('/api/v1/analytics/production/operations?period_from=2026-10-01&period_to=2026-10-02' . $extra)
            ->assertOk()
            ->json('data');
    }

    private function line(Machine $machine): ProductionBatchItem
    {
        $batch = ProductionBatch::create([
            'batch_title' => 'Partiya ' . $machine->name,
            'machine_id'  => $machine->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $this->admin->id,
        ]);

        return ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => ProductVariant::factory()->create([
                'product_size_id' => ProductSize::factory()->create(['width' => 200, 'length' => 300])->id,
            ])->id,
            'planned_quantity'    => 100,
            'produced_quantity'   => 0,
            'defect_quantity'     => 0,
        ]);
    }

    private function produced(ProductionBatchItem $line, User $by, string $at, int $count): void
    {
        for ($n = 0; $n < $count; $n++) {
            $this->event($line, $by, $at, ProductionEvent::TYPE_PRODUCED, 1);
        }
    }

    private function event(ProductionBatchItem $line, User $by, string $at, string $type, int $qty, ?string $reason = null): void
    {
        ProductionEvent::create([
            'production_batch_item_id' => $line->id,
            'event_type'               => $type,
            'quantity'                 => $qty,
            'occurred_at'              => $at,
            'user_id'                  => $by->id,
            'reason'                   => $reason,
            'created_at'               => $at,
        ]);
    }
}
