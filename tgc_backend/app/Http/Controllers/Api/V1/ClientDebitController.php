<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ClientDebitSummaryResource;
use App\Http\Resources\ClientResource;
use App\Models\Client;
use App\Services\ClientDebitService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ClientDebitController extends Controller
{
    public function __construct(private readonly ClientDebitService $service) {}

    /**
     * GET /api/v1/clients/debits
     *
     * Paginated list of all clients with their total debit (shipped),
     * total credit (paid), and current balance.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $paginator = $this->service->getSummaries(
            filters: [
                'search'      => $request->input('search'),
                'region'      => $request->input('region'),
                'has_balance' => $request->boolean('has_balance'),
            ],
            perPage: $request->integer('per_page', 20),
        );

        return ClientDebitSummaryResource::collection($paginator);
    }

    /**
     * GET /api/v1/clients/{client}/debit-ledger
     *
     * Full chronological debit/credit ledger for a single client
     * with shipment rows (debit) and payment rows (credit), plus
     * a running balance column and an overall summary.
     */
    public function ledger(Client $client): JsonResponse
    {
        $data = $this->service->getLedger($client);

        return response()->json([
            'client'  => new ClientResource($client),
            'summary' => $data['summary'],
            'ledger'  => $data['ledger'],
        ]);
    }
}
