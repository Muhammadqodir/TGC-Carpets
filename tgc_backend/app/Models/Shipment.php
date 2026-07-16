<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Shipment extends Model
{
    use HasFactory;

    const BASE_CURRENCY = 'USD';

    protected $fillable = [
        'client_id',
        'user_id',
        'order_id',
        'shipment_datetime',
        'notes',
        'pdf_path',
        'invoice_path',
        'xlsx_path',
        'currency',
        'exchange_rate',
        'vat_rate',
        'vat_amount',
    ];

    protected function casts(): array
    {
        return [
            'shipment_datetime' => 'datetime',
            'exchange_rate'     => 'decimal:8',
            'vat_rate'          => 'decimal:4',
            'vat_amount'        => 'decimal:2',
        ];
    }

    /**
     * SUM(line net) — every operand already 2dp (ShipmentItem::lineTotal()
     * rounds once), so this addition is exact and the printed lines sum
     * to the printed subtotal. Requires items.variant.productColor.product
     * and items.variant.productSize to be loaded.
     */
    public function subtotal(): string
    {
        return $this->items->reduce(fn ($carry, ShipmentItem $item) => bcadd($carry, $item->lineTotal(), 2), '0.00');
    }

    /** subtotal + vat_amount — both already 2dp, exact. */
    public function total(): string
    {
        return bcadd($this->subtotal(), (string) $this->getRawOriginal('vat_amount'), 2);
    }

    /**
     * total converted to the base currency, using THIS document's own
     * frozen exchange_rate — never a rate looked up at read time. A paid
     * invoice must not change value because a rate moved later. See
     * instructions/phase-3/04-currency-vat-discount.md.
     */
    public function baseTotal(): string
    {
        $rate = (string) $this->getRawOriginal('exchange_rate');

        return bcadd(bcmul($this->total(), $rate, 8), '0.005', 2);
    }

    public function currencySymbol(): string
    {
        return match ($this->currency) {
            'USD'   => '$',
            'UZS'   => 'so\'m',
            default => (string) $this->currency,
        };
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(ShipmentItem::class);
    }
}
