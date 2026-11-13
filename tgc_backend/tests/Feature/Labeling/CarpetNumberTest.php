<?php

namespace Tests\Feature\Labeling;

use App\Models\CarpetNumberBlock;
use App\Models\LabelReprint;
use App\Models\Machine;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Every new label carries its own 12-digit number. The label is already out of
 * the printer when the server hears about it, so whatever is wrong with a
 * number, the carpet must still count.
 */
class CarpetNumberTest extends TestCase
{
    use RefreshDatabase;

    private User $shift;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shift = User::factory()->labelManager()->create();
    }

    public function test_the_number_format_is_pinned(): void
    {
        // The app's carpet_number_test.dart pins the same numbers.
        $this->assertSame('210000000010', CarpetNumberBlock::numberFor(1));
        $this->assertSame('211234567898', CarpetNumberBlock::numberFor(123456789));

        $this->assertTrue(CarpetNumberBlock::isValidNumber('210000000010'));
        $this->assertFalse(CarpetNumberBlock::isValidNumber('210000000011'), 'wrong check digit');
        $this->assertFalse(CarpetNumberBlock::isValidNumber('220000000017'), 'wrong prefix');
        $this->assertFalse(CarpetNumberBlock::isValidNumber('21000000001'), 'too short');
    }

    public function test_blocks_never_overlap(): void
    {
        $first  = $this->issueBlock()->assertOk();
        $second = $this->issueBlock()->assertOk();

        $this->assertSame(CarpetNumberBlock::BLOCK_SIZE - 1, $first->json('last_serial') - $first->json('first_serial'));
        $this->assertSame($first->json('last_serial') + 1, $second->json('first_serial'));
        $this->assertSame($this->shift->id, CarpetNumberBlock::query()->first()->issued_to);
    }

    public function test_a_block_needs_a_logged_in_user(): void
    {
        $this->postJson('/api/v1/production-batches-print-labels/number-block')->assertUnauthorized();
    }

    public function test_a_counted_print_keeps_its_number_and_a_retry_changes_nothing(): void
    {
        $line = $this->line(planned: 2);
        $key  = (string) Str::uuid();

        $this->print($line, '210000000010', key: $key)->assertJsonPath('counted', true);
        $this->print($line, '210000000010', key: $key)->assertJsonPath('counted', true);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertSame('210000000010', ProductionUnit::where('production_batch_item_id', $line->id)->sole()->carpet_number);
    }

    public function test_a_reprint_repeats_the_number_without_counting(): void
    {
        $line = $this->line(planned: 2);
        $this->print($line, '210000000010');

        $this->print($line, '210000000010', reprint: true)->assertJsonPath('counted', false);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertSame('210000000010', ProductionUnit::where('production_batch_item_id', $line->id)->sole()->carpet_number);
        $this->assertSame('210000000010', LabelReprint::where('production_batch_item_id', $line->id)->sole()->carpet_number);
    }

    public function test_a_print_past_the_plan_keeps_its_number_on_the_reprint_record(): void
    {
        $line = $this->line(planned: 1);
        $this->print($line, '210000000010');

        $this->print($line, '210000000027')->assertJsonPath('counted', false);

        $this->assertSame('210000000027', LabelReprint::where('production_batch_item_id', $line->id)->sole()->carpet_number);
    }

    public function test_a_number_another_carpet_has_is_left_off_and_the_carpet_still_counts(): void
    {
        $line = $this->line(planned: 2);
        $this->print($line, '210000000010');

        $this->print($line, '210000000010')->assertJsonPath('counted', true);

        $this->assertSame(2, $line->fresh()->produced_quantity);
        $numbers = ProductionUnit::where('production_batch_item_id', $line->id)->orderBy('id')->pluck('carpet_number')->all();
        $this->assertSame(['210000000010', null], $numbers);
    }

    public function test_an_invalid_number_is_left_off_and_the_carpet_still_counts(): void
    {
        $line = $this->line(planned: 1);

        $this->print($line, '999')->assertJsonPath('counted', true);

        $this->assertSame(1, $line->fresh()->produced_quantity);
        $this->assertNull(ProductionUnit::where('production_batch_item_id', $line->id)->sole()->carpet_number);
    }

    public function test_an_old_app_without_numbers_keeps_working(): void
    {
        $line = $this->line(planned: 1);

        $this->print($line, null)->assertJsonPath('counted', true);

        $this->assertNull(ProductionUnit::where('production_batch_item_id', $line->id)->sole()->carpet_number);
    }

    public function test_an_undone_label_keeps_its_number_so_it_is_never_used_again(): void
    {
        $line = $this->line(planned: 1);
        $key  = (string) Str::uuid();
        $this->print($line, '210000000010', key: $key);

        $this->actingAs($this->shift, 'sanctum')
            ->postJson('/api/v1/production-batches-print-labels/undo', ['key' => $key])
            ->assertOk()
            ->assertJsonPath('status', 'undone');

        $unit = ProductionUnit::where('production_batch_item_id', $line->id)->sole();
        $this->assertSame(ProductionUnit::STATUS_SCRAPPED, $unit->status);
        $this->assertSame('210000000010', $unit->carpet_number);
    }

    private function issueBlock(): TestResponse
    {
        return $this->actingAs($this->shift, 'sanctum')
            ->postJson('/api/v1/production-batches-print-labels/number-block');
    }

    private function line(int $planned): ProductionBatchItem
    {
        $batch = ProductionBatch::create([
            'batch_title' => 'Sintetik partiya',
            'machine_id'  => Machine::factory()->create()->id,
            'type'        => ProductionBatch::TYPE_FOR_STOCK,
            'status'      => ProductionBatch::STATUS_IN_PROGRESS,
            'created_by'  => $this->shift->id,
        ]);

        return ProductionBatchItem::create([
            'production_batch_id' => $batch->id,
            'source_type'         => ProductionBatchItem::SOURCE_STOCK_REQUEST,
            'product_variant_id'  => ProductVariant::factory()->create()->id,
            'planned_quantity'    => $planned,
            'produced_quantity'   => 0,
            'defect_quantity'     => 0,
        ]);
    }

    private function print(ProductionBatchItem $line, ?string $number, bool $reprint = false, ?string $key = null): TestResponse
    {
        return $this->actingAs($this->shift, 'sanctum')
            ->postJson("/api/v1/production-batches/{$line->production_batch_id}/items/{$line->id}/print-label", array_filter([
                'idempotency_key' => $key ?? (string) Str::uuid(),
                'reprint'         => $reprint,
                'carpet_number'   => $number,
            ], fn ($value) => $value !== null))
            ->assertOk();
    }
}
