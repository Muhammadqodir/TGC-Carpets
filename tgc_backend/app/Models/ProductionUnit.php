<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionUnit extends Model
{
    const STATUS_GOOD     = 'good';     // printed, on the floor, not yet received into a warehouse
    const STATUS_DEFECT   = 'defect';   // found defective; excluded from produced counts
    const STATUS_SCRAPPED = 'scrapped'; // physically destroyed; terminal
    const STATUS_RECEIVED = 'received'; // booked into a warehouse by a document
    const STATUS_SHIPPED  = 'shipped';  // left on a shipment

    /** A unit in one of these statuses was produced output; defect/scrapped were not. */
    const PRODUCED_STATUSES = [
        self::STATUS_GOOD,
        self::STATUS_RECEIVED,
        self::STATUS_SHIPPED,
    ];

    protected $fillable = [
        'production_batch_item_id',
        'serial',
        'printed_by',
        'printed_at',
        'status',
        'warehouse_document_item_id',
        'shipment_item_id',
        'reprint_count',
        'backfilled_at',
    ];

    protected function casts(): array
    {
        return [
            'printed_at'    => 'datetime',
            'reprint_count' => 'integer',
            'backfilled_at' => 'datetime',
        ];
    }

    public function batchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class, 'production_batch_item_id');
    }

    public function printedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'printed_by');
    }

    public function warehouseDocumentItem(): BelongsTo
    {
        return $this->belongsTo(WarehouseDocumentItem::class);
    }

    public function shipmentItem(): BelongsTo
    {
        return $this->belongsTo(ShipmentItem::class);
    }

    public function isBackfilled(): bool
    {
        return $this->backfilled_at !== null;
    }
}
