<?php

namespace App\Console\Commands;

use App\Models\ProductColor;
use App\Services\ProductImageThumbnailer;
use Illuminate\Console\Command;

/**
 * Makes the small list-screen copy of every product photo that lacks one.
 * Safe to re-run: existing thumbnails are skipped unless --force.
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

        $made = $failed = 0;
        $bar = $this->output->createProgressBar($images->count());

        foreach ($images as $image) {
            ProductImageThumbnailer::generate($image, (bool) $this->option('force')) ? $made++ : $failed++;
            $bar->advance();
        }

        $bar->finish();
        $this->newLine();
        $this->info("Thumbnails ready: {$made}. Failed or original missing: {$failed}.");

        return self::SUCCESS;
    }
}
