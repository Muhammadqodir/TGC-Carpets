<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Payment\StorePaymentRequest;
use App\Http\Resources\PaymentResource;
use App\Models\Payment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PaymentController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $payments = Payment::with(['client', 'user', 'order'])
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->integer('client_id')))
            ->when($request->filled('order_id'),  fn ($q) => $q->where('order_id',  $request->integer('order_id')))
            ->when($request->filled('date_from'),  fn ($q) => $q->whereDate('created_at', '>=', $request->date_from))
            ->when($request->filled('date_to'),    fn ($q) => $q->whereDate('created_at', '<=', $request->date_to))
            ->latest()
            ->paginate($request->integer('per_page', 50));

        return PaymentResource::collection($payments);
    }

    public function store(StorePaymentRequest $request): JsonResponse
    {
        $payment = Payment::create([
            ...$request->validated(),
            'user_id' => $request->user()->id,
        ]);

        $payment->load(['client', 'user', 'order']);

        return response()->json(['data' => new PaymentResource($payment)], 201);
    }

    public function show(Payment $payment): JsonResponse
    {
        $payment->load(['client', 'user', 'order']);

        return response()->json(['data' => new PaymentResource($payment)]);
    }

    public function destroy(Payment $payment): JsonResponse
    {
        $payment->delete();

        return response()->json(null, 204);
    }
}
