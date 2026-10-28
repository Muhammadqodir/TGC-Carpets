<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class ProductVariant extends Model
{
    use HasFactory;

    protected $fillable = [
        'product_color_id',
        'product_size_id',
        'product_edge_id',
        'barcode_value',
        'sku_code',
    ];

    protected function casts(): array
    {
        return [
            'product_color_id' => 'integer',
            'product_size_id'  => 'integer',
            'product_edge_id'  => 'integer',
        ];
    }

    // ── SKU generation ────────────────────────────────────────────────────────

    /**
     * Generate a human-readable SKU for a variant.
     *
     * Format: TGC-{NAME}-Q{quality_id}-T{type_id}-{COLOR}-{LxW}-E{edge_code}
     * Example: TGC-7126-Q1-T2-KREM-200x300-ER
     */
    public static function generateSku(
        string $name,
        ?int $qualityId,
        ?int $typeId,
        string $colorName,
        ?ProductSize $size,
        ?string $edgeCode = null
    ): string {
        $sku = 'TGC-' . strtoupper(Str::slug($name, '_'));

        if ($qualityId) {
            $sku .= '-Q' . $qualityId;
        }
        if ($typeId) {
            $sku .= '-T' . $typeId;
        }

        $sku .= '-' . strtoupper(Str::slug($colorName, '_'));

        if ($size) {
            $sku .= '-' . $size->width . 'x' . $size->length;
        }

        if ($edgeCode) {
            $sku .= '-E' . strtoupper($edgeCode);
        }

        return $sku;
    }

    // ── Barcode ───────────────────────────────────────────────────────────────

    /**
     * First five digits of every product barcode printed on a label.
     *
     * Some clients' systems accept digits only, so the barcode is an EAN-13
     * instead of the old "TGC-00000042". TGC has no GS1 company prefix, so the
     * number sits in GS1's in-store range (starting with 2). GS1 never gives
     * those numbers to a manufacturer, so they can't clash with another
     * factory's barcode. "842" spells TGC on a phone keypad and keeps our codes
     * apart from the 2000000… numbers that shop software generates for itself.
     *
     * Never change it: clients keep these numbers in their own systems.
     */
    public const BARCODE_PREFIX = '29842';

    /** EAN-13 for a variant: the prefix, the variant id in 7 digits, a check digit. */
    public static function barcodeFor(int $variantId): string
    {
        if ($variantId < 1 || $variantId > 9_999_999) {
            throw new \InvalidArgumentException("Variant id {$variantId} does not fit the 7 digits of a product barcode.");
        }

        $digits = self::BARCODE_PREFIX . str_pad((string) $variantId, 7, '0', STR_PAD_LEFT);

        return $digits . self::ean13CheckDigit($digits);
    }

    /**
     * The variant id behind a product barcode: the EAN-13 from barcodeFor(), or
     * the "TGC-00000042" / "TGC-VAR-00000042" still printed on older labels.
     */
    public static function idFromBarcode(string $barcode): ?int
    {
        $barcode = trim($barcode);

        if (preg_match('/^TGC-(?:VAR-)?(\d{8})$/', $barcode, $m)) {
            return (int) $m[1] ?: null;
        }

        if (preg_match('/^' . self::BARCODE_PREFIX . '(\d{7})(\d)$/', $barcode, $m)
            && self::ean13CheckDigit(substr($barcode, 0, 12)) === $m[2]) {
            return (int) $m[1] ?: null;
        }

        return null;
    }

    private static function ean13CheckDigit(string $twelveDigits): string
    {
        $sum = 0;
        foreach (str_split($twelveDigits) as $i => $digit) {
            $sum += (int) $digit * ($i % 2 === 0 ? 1 : 3);
        }

        return (string) ((10 - $sum % 10) % 10);
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productColor(): BelongsTo
    {
        return $this->belongsTo(ProductColor::class);
    }

    public function productSize(): BelongsTo
    {
        // withTrashed: a hidden size/edge still belongs to variants that use it.
        return $this->belongsTo(ProductSize::class)->withTrashed();
    }

    public function productEdge(): BelongsTo
    {
        return $this->belongsTo(ProductEdge::class)->withTrashed();
    }

    public function warehouseDocumentItems(): HasMany
    {
        return $this->hasMany(WarehouseDocumentItem::class);
    }

    /** Cancelled shipments excluded — see OrderItem::shipmentItems(). */
    public function shipmentItems(): HasMany
    {
        return $this->hasMany(ShipmentItem::class)
            ->whereHas('shipment', fn ($q) => $q->whereNull('canceled_at'));
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    // ── Convenience accessors ─────────────────────────────────────────────────

    /**
     * Shortcut to the parent product (through product_color).
     */
    public function product(): BelongsTo
    {
        // Eager-load via productColor.product — this accessor loads it if needed.
        return $this->productColor()->getRelated()->belongsTo(Product::class);
    }

    /**
     * Human-readable label: "Carpet Name (krem) 200x300 [R]".
     */
    public function label(): string
    {
        $pc   = $this->productColor;
        $name = $pc?->product?->name ?? "Product #?";
        $color = $pc?->color?->name ?? '';
        $size = $this->productSize
            ? " {$this->productSize->width}x{$this->productSize->length}"
            : '';
        $edge = $this->productEdge
            ? " [{$this->productEdge->code}]"
            : '';

        return trim("{$name} ({$color}){$size}{$edge}");
    }
}
