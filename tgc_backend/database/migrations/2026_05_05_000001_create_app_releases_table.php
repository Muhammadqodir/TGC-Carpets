<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('app_releases', function (Blueprint $table): void {
            $table->id();

            // android | windows
            $table->enum('platform', ['android', 'windows']);

            // Human-readable version string, e.g. "1.2.3"
            $table->string('version', 20);

            // Monotonically increasing build number (matches Flutter's buildNumber)
            $table->unsignedInteger('build_code');

            // Whether clients MUST install this update before proceeding
            $table->boolean('is_required')->default(false);

            // Relative path inside the public storage disk, e.g. "releases/android-uuid.apk"
            $table->string('file_path');

            // SHA-256 hex digest (64 chars) — computed server-side on upload
            $table->char('sha256', 64);

            // Release notes (Uzbek or Russian)
            $table->text('changelog')->nullable();

            $table->foreignId('created_by')
                ->constrained('users')
                ->restrictOnDelete();

            $table->timestamps();

            // Efficiently find the latest release for a given platform
            $table->index(['platform', 'build_code'], 'app_releases_platform_build_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_releases');
    }
};
