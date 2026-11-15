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
     * First digit of every product barcode printed on a label since November
     * 2026: an EAN-8 of "5", the variant id in 6 digits and a check digit
     * ("50059843" for variant 5984). Short enough that a PDA aimed at the
     * label's 21 carpet number does not catch it instead.
     *
     * TGC has no GS1 prefix (the user's decision, 2026-09-17), so a shop
     * system could in theory hold a foreign retail product with the same
     * 8 digits; the user accepted that on 2026-11-15.
     *
     * Never change it again: clients keep these numbers in their own systems.
     */
    public const BARCODE_PREFIX = '5';

    /**
     * The EAN-13 printed from 2026-09-17 to 2026-11-15 ("29842" + 7-digit id +
     * check). Still on carpets and in clients' systems, so it keeps resolving.
     */
    public const LEGACY_BARCODE_PREFIX = '29842';

    /** EAN-8 for a variant: the prefix, the variant id in 6 digits, a check digit. */
    public static function barcodeFor(int $variantId): string
    {
        if ($variantId < 1 || $variantId > 999_999) {
            throw new \InvalidArgumentException("Variant id {$variantId} does not fit the 6 digits of a product barcode.");
        }

        $digits = self::BARCODE_PREFIX . str_pad((string) $variantId, 6, '0', STR_PAD_LEFT);

        return $digits . self::eanCheckDigit($digits);
    }

    /** The 13-digit barcode a variant had before November 2026. */
    public static function legacyBarcodeFor(int $variantId): string
    {
        if ($variantId < 1 || $variantId > 9_999_999) {
            throw new \InvalidArgumentException("Variant id {$variantId} does not fit the 7 digits of a product barcode.");
        }

        $digits = self::LEGACY_BARCODE_PREFIX . str_pad((string) $variantId, 7, '0', STR_PAD_LEFT);

        return $digits . self::eanCheckDigit($digits);
    }

    /**
     * The variant id behind a product barcode: the EAN-8 from barcodeFor(),
     * the EAN-13 printed before it, or the "TGC-00000042" / "TGC-VAR-00000042"
     * on the oldest labels.
     */
    public static function idFromBarcode(string $barcode): ?int
    {
        $barcode = trim($barcode);

        if (preg_match('/^TGC-(?:VAR-)?(\d{8})$/', $barcode, $m)) {
            return (int) $m[1] ?: null;
        }

        foreach ([[self::BARCODE_PREFIX, 6], [self::LEGACY_BARCODE_PREFIX, 7]] as [$prefix, $idDigits]) {
            if (preg_match('/^' . $prefix . '(\d{' . $idDigits . '})(\d)$/', $barcode, $m)
                && self::eanCheckDigit(substr($barcode, 0, -1)) === $m[2]) {
                return (int) $m[1] ?: null;
            }
        }

        return null;
    }

    /**
     * The EAN/UPC check digit: weights 3 and 1 alternating from the rightmost
     * data digit, so one function serves EAN-8 and EAN-13.
     */
    private static function eanCheckDigit(string $digits): string
    {
        $sum = 0;
        foreach (array_reverse(str_split($digits)) as $i => $digit) {
            $sum += (int) $digit * ($i % 2 === 0 ? 3 : 1);
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
