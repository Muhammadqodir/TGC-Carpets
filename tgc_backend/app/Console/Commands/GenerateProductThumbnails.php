<?php

namespace App\Console\Commands;

use App\Models\ProductColor;
use App\Services\ProductImageThumbnailer;
use Illuminate\Console\Command;

/**
 * Makes the small list-screen copy of every product photo that lacks one.
 * Safe to re-run: existing thumbnails are skipped unless --force, which also
 * removes thumbnails that turn out no smaller than their original.
 * New uploads get theirs automatically (ProductColor::booted).
 */
class GenerateProductThumbnails extends Command
{
    protected $signature = 'products:thumbnails {--force : Rebuild thumbnails that already exist}';

    protected $description = 'Generate small JPEG thumbnails for product colour photos';

    public function handle(): int
    {
        if (! function_exists('imagecreatefromstring')) {
            $this->error('The PHP GD extension is not loaded; nothing was generated.');

            return self::FAILURE;
        }

        $images = ProductColor::query()
            ->whereNotNull('image')
            ->where('image', '!=', '')
            ->distinct()
            ->pluck('image');

        $counts = [];
        $bar = $this->output->createProgressBar($images->count());

        foreach ($images as $image) {
            $status = ProductImageThumbnailer::generate($image, (bool) $this->option('force'));
            $counts[$status] = ($counts[$status] ?? 0) + 1;
            $bar->advance();
        }

        $bar->finish();
        $this->newLine();
        $this->info(sprintf(
            'Made: %d. Already there: %d. Original already small (no thumbnail, app shows the original): %d. Failed or original missing: %d.',
            $counts[ProductImageThumbnailer::MADE] ?? 0,
            $counts[ProductImageThumbnailer::EXISTS] ?? 0,
            $counts[ProductImageThumbnailer::NOT_SMALLER] ?? 0,
            $counts[ProductImageThumbnailer::FAILED] ?? 0,
        ));

        return self::SUCCESS;
    }
}
