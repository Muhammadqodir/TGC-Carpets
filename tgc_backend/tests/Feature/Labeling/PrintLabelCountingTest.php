<?php

namespace Tests\Feature\Labeling;

use App\Models\LabelReprint;
use App\Models\Machine;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * A batch line planned for 2 carpets, where one label tears before it goes on
 * a carpet: every label printed is on record with who and when, but only
 * carpets are counted, and never more than the plan.
 */
class PrintLabelCountingTest extends TestCase
{
    use RefreshDatabase;

    private User $shift1;

    private User $shift2;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shift1 = User::factory()->labelManager()->create(['name' => '1 SMENA (YORLIQ)']);
        $this->shift2 = User::factory()->labelManager()->create(['name' => '2 SMENA (YORLIQ)']);
    }

    public function test_torn_last_label_reprinted_counts_two_carpets_and_records_three_labels(): void
    {
        $line = $this->line(planned: 2);

        $this->print($line)->assertJsonPath('counted', true);
        $this->print($line)->assertJsonPath('counted', true);
        // The second label tore: the line is done, so the worker reprints it.
        $this->print($line, reprint: true)->assertJsonPath('counted', false);

        $this->assertSame(2, $line->fresh()->produced_quantity);
        $this->assertSame(ProductionBatch::STATUS_COMPLETED, $line->productionBatch->fresh()->status);
        $this->assertSame(2, ProductionUnit::where('production_batch_item_id', $line->id)->count());
        $this->assertSame([LabelReprint::REASON_REPRINT], LabelReprint::where('production_batch_item_id', $line->id)->pluck('reason')->all());
    }

    public function test_torn_first_label_reprinted_does_not_use_up_the_second_carpet(): void
    {
        $line = $this->line(planned: 2);

        $this->print($line);
        $this->print($line, reprint: true)->assertJsonPath('counted', false);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertSame(ProductionBatch::STATUS_IN_PROGRESS, $line->productionBatch->fresh()->status);

        $this->print($line)->assertJsonPath('counted', true);
        $this->assertSame(2, $line->fresh()->produced_quantity);
    }

    public function test_a_print_past_the_plan_is_recorded_not_counted(): void
    {
        $line = $this->line(planned: 2);

        $this->print($line);
        $this->print($line);
        // The 2026-08-28 case: a second double click reached the server after the plan was met.
        $this->print($line, by: $this->shift2)
            ->assertOk()
            ->assertJsonPath('counted', false)
            ->assertJsonPath('unit', null)
            ->assertJsonPath('data.produced_quantity', 2);

        $this->assertSame(2, $line->fresh()->produced_quantity);
        $this->assertSame(2, (int) ProductionEvent::where('production_batch_item_id', $line->id)->sum('quantity'));
        $reprint = LabelReprint::where('production_batch_item_id', $line->id)->sole();
        $this->assertSame(LabelReprint::REASON_OVER_TARGET, $reprint->reason);
        $this->assertSame($this->shift2->id, $reprint->printed_by);
    }

    public function test_defects_lower_the_plan_a_line_can_count_to(): void
    {
        $line = $this->line(planned: 3, defect: 1);

        $this->print($line);
        $this->print($line);
        $this->print($line)->assertJsonPath('counted', false);

        $this->assertSame(2, $line->fresh()->produced_quantity);
    }

    public function test_retry_of_the_print_that_met_the_plan_replays_instead_of_becoming_a_reprint(): void
    {
        $line = $this->line(planned: 1);
        $key  = (string) Str::uuid();

        $this->print($line, key: $key)->assertJsonPath('counted', true);
        $this->print($line, key: $key)->assertJsonPath('counted', true);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertSame(0, LabelReprint::count());
    }

    public function test_retried_reprint_is_recorded_once(): void
    {
        $line = $this->line(planned: 2);
        $key  = (string) Str::uuid();

        $this->print($line, reprint: true, key: $key);
        $this->print($line, reprint: true, key: $key);

        $this->assertSame(1, LabelReprint::count());
        $this->assertSame(0, $line->fresh()->produced_quantity);
    }

    public function test_scan_lists_reprints_among_the_prints(): void
    {
        $line = $this->line(planned: 1);
        $this->print($line);
        $this->print($line, reprint: true, by: $this->shift2);
        $this->print($line, by: $this->shift2);

        $prints = $this->actingAs($this->shift1, 'sanctum')
            ->getJson("/api/v1/production-batches-scan?code=P{$line->production_batch_id}%20I{$line->id}")
            ->assertOk()
            ->json('data.label_prints.prints');

        $this->assertSame(['print', 'reprint', 'over_target'], array_column($prints, 'kind'));
        $this->assertSame(['1 SMENA (YORLIQ)', '2 SMENA (YORLIQ)', '2 SMENA (YORLIQ)'], array_column($prints, 'printed_by_name'));
    }

    public function test_fix_command_turns_double_counted_carpets_back_into_reprints(): void
    {
        // What the old code left behind: planned 2, counted 3 by a double click.
        $line = $this->line(planned: 2);
        foreach ([$this->shift1, $this->shift2, $this->shift2] as $n => $by) {
            ProductionEvent::create([
                'production_batch_item_id' => $line->id,
                'event_type'               => ProductionEvent::TYPE_PRODUCED,
                'quantity'                 => 1,
                'occurred_at'              => now()->addSeconds($n),
                'user_id'                  => $by->id,
                'created_at'               => now(),
            ]);
            $unit = ProductionUnit::create([
                'production_batch_item_id' => $line->id,
                'serial'                   => 'PENDING',
                'printed_by'               => $by->id,
                'printed_at'               => now()->addSeconds($n),
                'status'                   => ProductionUnit::STATUS_GOOD,
            ]);
            $unit->update(['serial' => sprintf('TGC-U-%08d', $unit->id)]);
        }
        $line->update(['produced_quantity' => 3]);
        $admin = User::factory()->admin()->create();
        $healthy = $this->line(planned: 2);

        Artisan::call('production:fix-over-target');
        $this->assertSame(3, $line->fresh()->produced_quantity, 'a dry run writes nothing');

        $this->assertSame(1, Artisan::call('production:fix-over-target', ['--apply' => true]), '--apply without --user is refused');
        $this->assertSame(3, $line->fresh()->produced_quantity);

        Artisan::call('production:fix-over-target', ['--apply' => true, '--user' => $admin->id]);

        $this->assertSame(2, $line->fresh()->produced_quantity);
        $this->assertSame(2, (int) ProductionEvent::where('production_batch_item_id', $line->id)->sum('quantity'));
        $this->assertSame(2, ProductionUnit::where('production_batch_item_id', $line->id)->count());
        $reprint = LabelReprint::where('production_batch_item_id', $line->id)->sole();
        $this->assertSame(LabelReprint::REASON_OVER_TARGET, $reprint->reason);
        $this->assertSame($this->shift2->id, $reprint->printed_by);
        $this->assertSame(0, $healthy->fresh()->produced_quantity);

        Artisan::call('production:fix-over-target', ['--apply' => true, '--user' => $admin->id]);
        $this->assertSame(2, $line->fresh()->produced_quantity, 'running it again changes nothing');
        $this->assertSame(1, LabelReprint::count());

        $this->assertStringContainsString('no drift', $this->reconcileUnits());
    }

    public function test_fix_command_leaves_lines_the_warehouse_already_received_past_the_plan(): void
    {
        $line = $this->line(planned: 1);
        $line->update(['produced_quantity' => 2, 'warehouse_received_quantity' => 2]);

        Artisan::call('production:fix-over-target', ['--apply' => true, '--user' => $this->shift1->id]);

        $this->assertSame(2, $line->fresh()->produced_quantity);
        $this->assertStringContainsString('SKIPPED', Artisan::output());
    }

    private function line(int $planned, int $defect = 0): ProductionBatchItem
    {
        $batch = ProductionBatch::create([
            'batch_title' => 'Sintetik partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $this->shift1->id,
        ]);

        return ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => ProductVariant::factory()->create()->id,
            'planned_quantity'    => $planned,
            'produced_quantity'   => 0,
            'defect_quantity'     => $defect,
        ]);
    }

    private function print(ProductionBatchItem $line, bool $reprint = false, ?User $by = null, ?string $key = null): TestResponse
    {
        return $this->actingAs($by ?? $this->shift1, 'sanctum')
            ->postJson("/api/v1/production-batches/{$line->production_batch_id}/items/{$line->id}/print-label", [
                'idempotency_key' => $key ?? (string) Str::uuid(),
                'reprint'         => $reprint,
            ])
            ->assertOk();
    }

    private function reconcileUnits(): string
    {
        Artisan::call('production:reconcile-units');

        return Artisan::output();
    }
}
