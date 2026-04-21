<?php

namespace App\Services;

use App\Models\RawMaterialStockMovement;
use Illuminate\Support\Facades\DB;

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
}
