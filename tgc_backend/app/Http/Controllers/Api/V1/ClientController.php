<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Client\StoreClientRequest;
use App\Http\Requests\Client\UpdateClientRequest;
use App\Http\Resources\ClientResource;
use App\Models\Client;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ClientController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $clients = Client::query()
            ->when($request->filled('shop_name'),    fn ($q) => $q->where('shop_name',    'like', '%'.$request->shop_name.'%'))
            ->when($request->filled('contact_name'), fn ($q) => $q->where('contact_name', 'like', '%'.$request->contact_name.'%'))
            ->when($request->filled('phone'),        fn ($q) => $q->where('phone',        'like', '%'.$request->phone.'%'))
            ->when($request->filled('region'),       fn ($q) => $q->where('region',       $request->region))
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ClientResource::collection($clients);
    }

    public function store(StoreClientRequest $request): JsonResponse
    {
        // Idempotent create — return existing record if external_uuid already known
        if ($request->filled('external_uuid')) {
            $existing = Client::where('uuid', $request->external_uuid)->first();
            if ($existing) {
                return response()->json(['data' => new ClientResource($existing)], 200);
            }
        }

        $client = Client::create($request->validated());

        return response()->json(['data' => new ClientResource($client)], 201);
    }

    public function show(Client $client): JsonResponse
    {
        return response()->json(['data' => new ClientResource($client)]);
    }

    public function update(UpdateClientRequest $request, Client $client): JsonResponse
    {
        $client->update($request->validated());

        return response()->json(['data' => new ClientResource($client)]);
    }

    public function destroy(Client $client): JsonResponse
    {
        $client->delete();

        return response()->json(['message' => 'Client deleted successfully.']);
    }
}
