<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A run of carpet numbers issued to a printing PC in advance.
 *
 * A carpet number is 12 digits: "21", a 9-digit serial, and a check digit
 * calculated like a UPC-A's. Mirrored in the app's carpet_number.dart.
 *
 * The block's auto-increment id decides its serials, so two PCs asking at the
 * same moment can never get the same numbers, and no lock is needed. A block
 * lost with a reinstalled PC or a lost response only leaves a gap in the
 * numbers, which is harmless: there are about a billion of them.
 *
 * Never change BLOCK_SIZE or the number format: numbers already on carpets are
 * derived from them, and new blocks would overlap old ones.
 */
class CarpetNumberBlock extends Model
{
    const BLOCK_SIZE = 500;
    const PREFIX     = '21';
    const MAX_SERIAL = 999_999_999;

    const UPDATED_AT = null;

    protected $fillable = ['issued_to'];

    public function issuedToUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'issued_to');
    }

    public function firstSerial(): int
    {
        return ($this->id - 1) * self::BLOCK_SIZE + 1;
    }

    public function lastSerial(): int
    {
        return $this->id * self::BLOCK_SIZE;
    }

    public static function numberFor(int $serial): string
    {
        if ($serial < 1 || $serial > self::MAX_SERIAL) {
            throw new \InvalidArgumentException("Serial {$serial} does not fit a carpet number.");
        }

        $digits = self::PREFIX.str_pad((string) $serial, 9, '0', STR_PAD_LEFT);

        return $digits.self::checkDigit($digits);
    }

    public static function isValidNumber(string $number): bool
    {
        return preg_match('/^21\d{10}$/', $number) === 1
            && self::checkDigit(substr($number, 0, 11)) === $number[11];
    }

    private static function checkDigit(string $elevenDigits): string
    {
        $sum = 0;
        foreach (str_split($elevenDigits) as $i => $digit) {
            $sum += (int) $digit * ($i % 2 === 0 ? 3 : 1);
        }

        return (string) ((10 - $sum % 10) % 10);
    }
}
