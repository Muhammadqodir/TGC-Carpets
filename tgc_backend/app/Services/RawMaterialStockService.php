<?php

namespace App\Services;

use App\Models\RawMaterial;
use App\Models\RawMaterialStockMovement;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class RawMaterialStockService
{
    /**
     * Create multiple stock movements in a single transaction.
     *
     * @param  array{date_time: string, type: string, notes: ?string, items: array<array{material_id: int, quantity: float}>}  $data
     */
    public function storeBatch(array $data, int $userId): array
    {
        return DB::transaction(function () use ($data, $userId): array {
            if ($data['type'] === RawMaterialStockMovement::TYPE_SPENT) {
                $this->assertSufficientStock($data['items']);
            }

            $movements = [];

            foreach ($data['items'] as $item) {
                $movements[] = RawMaterialStockMovement::create([
                    'material_id' => $item['material_id'],
                    'user_id'     => $userId,
                    'date_time'   => $data['date_time'],
                    'type'        => $data['type'],
                    'quantity'    => $item['quantity'],
                    'notes'       => $data['notes'] ?? null,
                ]);
            }

            // Eager-load relationships for the response
            $ids = collect($movements)->pluck('id');

            return RawMaterialStockMovement::with(['material', 'user'])
                ->whereIn('id', $ids)
                ->get()
                ->all();
        });
    }

    /**
     * @param  array<int, array{material_id: int, quantity: string|float}>  $items
     *
     * INTERIM (phase-1 step 08): raw_materials is a proxy lock — the real
     * balance is a SUM over raw_material_stock_movements. This is currently
     * total, because storeBatch() is the only writer. Say so here because it
     * stops being true the moment a second writer appears.
     */
    private function assertSufficientStock(array $items): void
    {
        // Aggregate per material FIRST: two lines of the same material must be
        // checked against their combined total, not each against the full balance.
        $requestedPerMaterial = [];
        $lineIndexes          = [];

        foreach ($items as $index => $item) {
            $id = (int) $item['material_id'];
            $requestedPerMaterial[$id] = bcadd(
                $requestedPerMaterial[$id] ?? '0',
                (string) $item['quantity'],
                3
            );
            $lineIndexes[$id][] = $index;
        }

        // Stable lock order to avoid deadlocks between concurrent batches.
        $materialIds = array_keys($requestedPerMaterial);
        sort($materialIds);

        RawMaterial::whereIn('id', $materialIds)->orderBy('id')->lockForUpdate()->get();

        $errors = [];

        foreach ($requestedPerMaterial as $materialId => $requested) {
            $balance = $this->getBalance($materialId);

            if (bccomp($balance, $requested, 3) < 0) {
                $material   = RawMaterial::find($materialId);
                $unit       = $material?->unit ?? '';
                $firstIndex = $lineIndexes[$materialId][0];

                $errors["items.{$firstIndex}.quantity"] = [
                    sprintf(
                        'Insufficient stock for %s. Available: %s %s, Requested: %s %s.',
                        $material?->name ?? "material #{$materialId}",
                        $balance, $unit, $requested, $unit
                    ),
                ];
            }
        }

        if (! empty($errors)) {
            $this->reportOrReject($errors);
        }
    }

    /**
     * Gated behind config('raw_materials.enforce_stock_validation') —
     * log-only until a week of production logs is understood, because the
     * live app may already be posting spends that exceed the balance. See
     * instructions/phase-1/08-raw-material-validation-decimal.md.
     */
    private function reportOrReject(array $errors): void
    {
        if (! config('raw_materials.enforce_stock_validation', false)) {
            Log::warning('raw_material.validation.would_reject', [
                'violations' => $errors,
            ]);

            return;   // request proceeds exactly as it does today
        }

        throw ValidationException::withMessages($errors);
    }

    private function getBalance(int $materialId): string
    {
        $row = DB::table('raw_material_stock_movements')
            ->where('material_id', $materialId)
            ->selectRaw(
                "COALESCE(SUM(CASE WHEN type = 'received' THEN quantity ELSE 0 END), 0)"
                . " - COALESCE(SUM(CASE WHEN type = 'spent' THEN quantity ELSE 0 END), 0) AS balance"
            )
            ->first();

        return (string) ($row->balance ?? '0');
    }
}
