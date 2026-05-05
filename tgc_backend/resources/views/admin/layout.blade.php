<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'TGC Admin') — App Releases</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
          crossorigin="anonymous">
    <style>
        body { background: #f4f6f9; }
        .navbar-brand { font-weight: 700; letter-spacing: .5px; }
        .table th { white-space: nowrap; }
        .badge-android { background-color: #3ddc84; color: #000; }
        .badge-windows { background-color: #0078d4; }
        .sha256-cell { font-family: monospace; font-size: .75rem; word-break: break-all; }
    </style>
</head>
<body>

<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
    <div class="container">
        <a class="navbar-brand" href="{{ route('admin.app-releases.index') }}">
            🏭 TGC Admin — App Releases
        </a>
        <div class="ms-auto d-flex align-items-center gap-3">
            <span class="text-white-50 small">{{ Auth::user()->name }}</span>
            <form method="POST" action="{{ route('admin.app-releases.logout') }}">
                @csrf
                <button class="btn btn-outline-light btn-sm" type="submit">Chiqish</button>
            </form>
        </div>
    </div>
</nav>

<div class="container">
    @if (session('success'))
        <div class="alert alert-success alert-dismissible fade show" role="alert">
            {{ session('success') }}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    @endif

    @yield('content')
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmRA8MtZrGkpuTr3CqDRXIIQ27cg"
        crossorigin="anonymous"></script>
@stack('scripts')
</body>
</html>
