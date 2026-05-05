@extends('admin.layout')

@section('title', 'Yangi versiya yuklash')

@section('content')
<div class="d-flex align-items-center gap-2 mb-4">
    <a href="{{ route('admin.app-releases.index') }}" class="btn btn-outline-secondary btn-sm">← Orqaga</a>
    <h5 class="mb-0 fw-semibold">Yangi versiya yuklash</h5>
</div>

<div class="card border-0 shadow-sm" style="max-width: 640px;">
    <div class="card-body p-4">

        @if ($errors->any())
            <div class="alert alert-danger">
                <ul class="mb-0 ps-3">
                    @foreach ($errors->all() as $error)
                        <li>{{ $error }}</li>
                    @endforeach
                </ul>
            </div>
        @endif

        <form
            method="POST"
            action="{{ route('admin.app-releases.store') }}"
            enctype="multipart/form-data"
            novalidate
        >
            @csrf

            {{-- Platform --}}
            <div class="mb-3">
                <label class="form-label fw-semibold">Platforma <span class="text-danger">*</span></label>
                <div class="d-flex gap-3">
                    <div class="form-check">
                        <input
                            class="form-check-input"
                            type="radio"
                            name="platform"
                            id="platform_android"
                            value="android"
                            {{ old('platform', 'android') === 'android' ? 'checked' : '' }}
                        >
                        <label class="form-check-label" for="platform_android">
                            Android (.apk)
                        </label>
                    </div>
                    <div class="form-check">
                        <input
                            class="form-check-input"
                            type="radio"
                            name="platform"
                            id="platform_windows"
                            value="windows"
                            {{ old('platform') === 'windows' ? 'checked' : '' }}
                        >
                        <label class="form-check-label" for="platform_windows">
                            Windows (.exe)
                        </label>
                    </div>
                </div>
            </div>

            {{-- Version --}}
            <div class="row g-3 mb-3">
                <div class="col-sm-6">
                    <label for="version" class="form-label fw-semibold">
                        Versiya <span class="text-danger">*</span>
                    </label>
                    <input
                        type="text"
                        id="version"
                        name="version"
                        class="form-control @error('version') is-invalid @enderror"
                        value="{{ old('version') }}"
                        placeholder="1.2.3"
                        required
                    >
                    @error('version')
                        <div class="invalid-feedback">{{ $message }}</div>
                    @enderror
                </div>

                <div class="col-sm-6">
                    <label for="build_code" class="form-label fw-semibold">
                        Build raqami <span class="text-danger">*</span>
                    </label>
                    <input
                        type="number"
                        id="build_code"
                        name="build_code"
                        class="form-control @error('build_code') is-invalid @enderror"
                        value="{{ old('build_code') }}"
                        min="1"
                        placeholder="24"
                        required
                    >
                    @error('build_code')
                        <div class="invalid-feedback">{{ $message }}</div>
                    @enderror
                </div>
            </div>

            {{-- Required update toggle --}}
            <div class="mb-3 form-check">
                <input
                    type="checkbox"
                    class="form-check-input"
                    id="is_required"
                    name="is_required"
                    value="1"
                    {{ old('is_required') ? 'checked' : '' }}
                >
                <label class="form-check-label" for="is_required">
                    Majburiy yangilanish
                    <span class="text-muted small">(foydalanuvchi rad eta olmaydi)</span>
                </label>
            </div>

            {{-- File upload --}}
            <div class="mb-3">
                <label for="file" class="form-label fw-semibold">
                    Fayl <span class="text-danger">*</span>
                </label>
                <input
                    type="file"
                    id="file"
                    name="file"
                    class="form-control @error('file') is-invalid @enderror"
                    accept=".apk,.exe"
                    required
                >
                <div class="form-text">
                    Android uchun .apk, Windows uchun .exe. Maksimal hajm: 200&nbsp;MB.<br>
                    SHA-256 xesh server tomonida hisoblanadi va saqlanadi.
                </div>
                @error('file')
                    <div class="invalid-feedback">{{ $message }}</div>
                @enderror
            </div>

            {{-- Changelog --}}
            <div class="mb-4">
                <label for="changelog" class="form-label fw-semibold">O'zgarishlar (changelog)</label>
                <textarea
                    id="changelog"
                    name="changelog"
                    class="form-control @error('changelog') is-invalid @enderror"
                    rows="4"
                    placeholder="Yangi versiyada nima o'zgardi..."
                >{{ old('changelog') }}</textarea>
                @error('changelog')
                    <div class="invalid-feedback">{{ $message }}</div>
                @enderror
            </div>

            <div class="d-flex gap-2">
                <button type="submit" class="btn btn-dark" id="submitBtn">
                    Yuklash
                </button>
                <a href="{{ route('admin.app-releases.index') }}" class="btn btn-outline-secondary">
                    Bekor qilish
                </a>
            </div>
        </form>
    </div>
</div>
@endsection

@push('scripts')
<script>
    // Show upload progress indicator while form is submitting
    document.querySelector('form').addEventListener('submit', function () {
        const btn = document.getElementById('submitBtn');
        btn.disabled = true;
        btn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Yuklanmoqda…';
    });
</script>
@endpush
