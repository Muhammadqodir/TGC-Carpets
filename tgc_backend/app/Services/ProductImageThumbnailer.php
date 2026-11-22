<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;

/**
 * Small JPEG copies of product photos for list screens.
 *
 * Originals are phone photos and screenshots (often 1200×1600 to 4000×3000,
 * up to 4 MB). The label-print terminal shows six of them per page in cards a
 * few hundred pixels wide, so downloading and decoding the originals is what
 * made the photos slow. A thumbnail sits next to its original:
 *
 *   products/AbC123.png  →  products/thumbs/AbC123.jpg
 *
 * The original is never touched, and when a thumbnail is missing the API
 * simply leaves `thumb_url` null so the app falls back to the original.
 */
class ProductImageThumbnailer
{
    /**
     * The thumbnail is just big enough to cover a box of this size, the
     * largest a label-terminal card shows a photo (with some headroom for
     * screen scaling): portrait photos end up 800 wide, wide ones 500 tall.
     */
    public const COVER_WIDTH  = 800;
    public const COVER_HEIGHT = 500;

    private const QUALITY = 75;

    /** A thumbnail must be at most this share of the original's bytes. */
    private const MAX_SIZE_RATIO = 0.85;

    public const MADE        = 'made';
    public const EXISTS      = 'exists';
    public const NOT_SMALLER = 'not_smaller';
    public const FAILED      = 'failed';

    /** @var array<string, string|null> */
    private static array $urls = [];

    public static function thumbPath(string $image): string
    {
        $dir  = trim(dirname($image), './');
        $name = pathinfo($image, PATHINFO_FILENAME);

        return ($dir === '' ? '' : $dir . '/') . 'thumbs/' . $name . '.jpg';
    }

    /** Public URL of the thumbnail, or null when it has not been made. */
    public static function url(?string $image): ?string
    {
        if (! $image) {
            return null;
        }

        // One list response repeats the same colour many times: stat once.
        if (! array_key_exists($image, self::$urls)) {
            $disk  = Storage::disk('public');
            $thumb = self::thumbPath($image);
            self::$urls[$image] = $disk->exists($thumb) ? $disk->url($thumb) : null;
        }

        return self::$urls[$image];
    }

    /**
     * Writes the thumbnail for $image and returns one of the status consts.
     * When the photo is already small (or compresses better than our copy
     * would), no thumbnail is kept and the app shows the original instead.
     * Never throws: a failed thumbnail must not fail an upload.
     */
    public static function generate(string $image, bool $force = false): string
    {
        try {
            unset(self::$urls[$image]);
            $disk  = Storage::disk('public');
            $thumb = self::thumbPath($image);

            if (! $force && $disk->exists($thumb)) {
                return self::EXISTS;
            }
            if (! function_exists('imagecreatefromstring') || ! $disk->exists($image)) {
                return self::FAILED;
            }

            $original = $disk->get($image);
            $src = @imagecreatefromstring($original);
            if ($src === false) {
                return self::FAILED;
            }

            $w = imagesx($src);
            $h = imagesy($src);
            $scale = max(self::COVER_WIDTH / max(1, $w), self::COVER_HEIGHT / max(1, $h));
            if ($scale >= 1.0) {
                // Already no bigger than a card: a re-encode would only grow it.
                imagedestroy($src);
                $disk->delete($thumb);

                return self::NOT_SMALLER;
            }
            $tw = max(1, (int) round($w * $scale));
            $th = max(1, (int) round($h * $scale));

            $dst = imagecreatetruecolor($tw, $th);
            // JPEG has no alpha: put transparent PNG/WebP areas on white.
            imagefill($dst, 0, 0, imagecolorallocate($dst, 255, 255, 255));
            imagecopyresampled($dst, $src, 0, 0, 0, 0, $tw, $th, $w, $h);

            ob_start();
            imagejpeg($dst, null, self::QUALITY);
            $bytes = ob_get_clean();

            imagedestroy($src);
            imagedestroy($dst);

            if ($bytes === false || $bytes === '') {
                return self::FAILED;
            }
            if (strlen($bytes) > strlen($original) * self::MAX_SIZE_RATIO) {
                $disk->delete($thumb);

                return self::NOT_SMALLER;
            }

            return $disk->put($thumb, $bytes) ? self::MADE : self::FAILED;
        } catch (\Throwable $e) {
            Log::warning('Product thumbnail failed', ['image' => $image, 'error' => $e->getMessage()]);

            return self::FAILED;
        }
    }

    public static function delete(?string $image): void
    {
        if ($image) {
            unset(self::$urls[$image]);
            Storage::disk('public')->delete(self::thumbPath($image));
        }
    }
}
