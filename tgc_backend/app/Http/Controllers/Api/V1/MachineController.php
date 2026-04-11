<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MachineResource;
use App\Models\Machine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class MachineController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $machines = Machine::query()
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%' . $request->search . '%'))
            ->orderBy('name')
            ->paginate($request->integer('per_page', 50));

        return MachineResource::collection($machines);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name'       => ['required', 'string', 'max:255'],
            'model_name' => ['nullable', 'string', 'max:255'],
        ]);

        $machine = Machine::create($data);

        return response()->json(['data' => new MachineResource($machine)], 201);
    }

    public function show(Machine $machine): JsonResponse
    {
        return response()->json(['data' => new MachineResource($machine)]);
    }

    public function update(Request $request, Machine $machine): JsonResponse
    {
        $data = $request->validate([
            'name'       => ['sometimes', 'string', 'max:255'],
            'model_name' => ['nullable', 'string', 'max:255'],
        ]);

        $machine->update($data);

        return response()->json(['data' => new MachineResource($machine)]);
    }

    public function destroy(Machine $machine): JsonResponse
    {
        $machine->delete();

        return response()->json(['message' => 'Machine deleted.']);
    }
}
