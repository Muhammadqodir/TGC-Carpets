@extends('admin.layout')

@section('title', 'App Releases')

@section('content')
<div class="d-flex justify-content-between align-items-center mb-4">
    <h5 class="mb-0 fw-semibold">Barcha versiyalar</h5>
    <a href="{{ route('admin.app-releases.create') }}" class="btn btn-dark btn-sm">
        + Yangi versiya yuklash
    </a>
</div>

<div class="card border-0 shadow-sm">
    <div class="card-body p-0">
        @if ($releases->isEmpty())
            <p class="text-muted text-center py-5 mb-0">Hozircha versiyalar yo'q.</p>
        @else
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th>#</th>
                            <th>Platforma</th>
                            <th>Versiya</th>
                            <th>Build</th>
                            <th>Majburiy</th>
                            <th>SHA-256</th>
                            <th>Yuklagan</th>
                            <th>Sana</th>
                            <th>Harakatlar</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($releases as $release)
                        <tr>
                            <td class="text-muted small">{{ $release->id }}</td>
                            <td>
                                <span class="badge {{ $release->platform === 'android' ? 'badge-android' : 'badge-windows' }} text-capitalize">
                                    {{ $release->platform }}
                                </span>
                            </td>
                            <td class="fw-semibold">{{ $release->version }}</td>
                            <td>{{ $release->build_code }}</td>
                            <td>
                                @if ($release->is_required)
                                    <span class="badge bg-danger">Ha</span>
                                @else
                                    <span class="badge bg-secondary">Yo'q</span>
                                @endif
                            </td>
                            <td class="sha256-cell" title="{{ $release->sha256 }}">
                                {{ substr($release->sha256, 0, 12) }}…
                            </td>
                            <td class="small">{{ $release->creator?->name ?? '—' }}</td>
                            <td class="small text-nowrap">
                                {{ $release->created_at->format('d.m.Y H:i') }}
                            </td>
                            <td>
                                <div class="d-flex gap-2">
                                    <a href="{{ $release->getDownloadUrl() }}"
                                       class="btn btn-outline-primary btn-sm"
                                       target="_blank">
                                        Yuklab olish
                                    </a>
                                    <form
                                        method="POST"
                                        action="{{ route('admin.app-releases.destroy', $release) }}"
                                        onsubmit="return confirm('Versiyani o\'chirishni tasdiqlaysizmi?')"
                                    >
                                        @csrf
                                        @method('DELETE')
                                        <button type="submit" class="btn btn-outline-danger btn-sm">
                                            O'chirish
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </div>
</div>

@if ($releases->hasPages())
    <div class="mt-4 d-flex justify-content-center">
        {{ $releases->links() }}
    </div>
@endif
@endsection
