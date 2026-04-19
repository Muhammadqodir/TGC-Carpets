<?php

namespace App\Services;

use App\Models\Client;
use App\Models\Payment;
use App\Models\Shipment;
use Illuminate\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ClientDebitService
{
    /**
     * Return a paginated list of all clients enriched with:
     * - total_debit  : sum of all shipment item totals
     * - total_credit : sum of all payments
     * - balance      : total_debit - total_credit  (positive = client owes money)
     */
    public function getSummaries(array $filters = [], int $perPage = 20): LengthAwarePaginator
    {
        // Subquery: compute shipped amount per client.
        // For m² products: price × (length × width × quantity / 10 000)
        // For piece products: price × quantity
        $debitSub = DB::table('shipment_items as si')
            ->join('shipments as s',            's.id',  '=', 'si.shipment_id')
            ->join('product_variants as pv',    'pv.id', '=', 'si.product_variant_id')
            ->join('product_colors as pc',      'pc.id', '=', 'pv.product_color_id')
            ->join('products as p',             'p.id',  '=', 'pc.product_id')
            ->select(
                's.client_id',
                DB::raw("
                    SUM(
                        CASE
                            WHEN p.unit = 'm2' AND pv.length IS NOT NULL AND pv.width IS NOT NULL
                                THEN si.price * pv.length * pv.width * si.quantity / 10000.0
                            ELSE
                                si.quantity * si.price
                        END
                    ) AS total_debit
                ")
            )
            ->groupBy('s.client_id');

        // Subquery: sum payments per client
        $creditSub = DB::table('payments')
            ->select('client_id', DB::raw('SUM(amount) AS total_credit'))
            ->groupBy('client_id');

        return Client::query()
            ->leftJoinSub($debitSub, 'dbt', fn ($j) => $j->on('clients.id', '=', 'dbt.client_id'))
            ->leftJoinSub($creditSub, 'crd', fn ($j) => $j->on('clients.id', '=', 'crd.client_id'))
            ->select([
                'clients.*',
                DB::raw('COALESCE(dbt.total_debit,  0) AS total_debit'),
                DB::raw('COALESCE(crd.total_credit, 0) AS total_credit'),
                DB::raw('COALESCE(dbt.total_debit, 0) - COALESCE(crd.total_credit, 0) AS balance'),
            ])
            ->when(
                ! empty($filters['search']),
                fn ($q) => $q->where(function ($q2) use ($filters) {
                    $q2->where('clients.shop_name',    'like', '%'.$filters['search'].'%')
                       ->orWhere('clients.contact_name', 'like', '%'.$filters['search'].'%')
                       ->orWhere('clients.phone',        'like', '%'.$filters['search'].'%');
                })
            )
            ->when(
                ! empty($filters['region']),
                fn ($q) => $q->where('clients.region', $filters['region'])
            )
            ->when(
                isset($filters['has_balance']) && $filters['has_balance'],
                fn ($q) => $q->havingRaw('balance > 0')
            )
            ->latest('clients.created_at')
            ->paginate($perPage);
    }

    /**
     * Return a chronological ledger of all debits (shipments) and credits
     * (payments) for a specific client, plus a running balance.
     */
    public function getLedger(Client $client): array
    {
        // ── Collect shipment entries ──────────────────────────────────────
        $shipments = Shipment::with([
                'items.variant.productColor.product',
            ])
            ->where('client_id', $client->id)
            ->orderBy('shipment_datetime')
            ->get();

        $entries = [];

        foreach ($shipments as $shipment) {
            $total = 0.0;
            foreach ($shipment->items as $item) {
                $unit = $item->variant?->productColor?->product?->unit ?? 'piece';
                if ($unit === 'm2') {
                    $l = $item->variant?->length;
                    $w = $item->variant?->width;
                    if ($l && $w) {
                        $total += (float) $item->price * $l * $w * $item->quantity / 10000.0;
                    } else {
                        $total += (float) $item->quantity * (float) $item->price;
                    }
                } else {
                    $total += (float) $item->quantity * (float) $item->price;
                }
            }

            $entries[] = [
                'type'      => 'shipment',
                'date'      => $shipment->shipment_datetime?->toISOString(),
                'reference' => 'Shipment #'.$shipment->id,
                'notes'     => $shipment->notes,
                'debit'     => round($total, 2),
                'credit'    => 0.0,
                'source_id' => $shipment->id,
                'pdf_url'   => $shipment->pdf_path
                    ? Storage::disk('public')->url($shipment->pdf_path)
                    : null,
            ];
        }

        // ── Collect payment entries ───────────────────────────────────────
        $payments = Payment::where('client_id', $client->id)
            ->orderBy('created_at')
            ->get();

        foreach ($payments as $payment) {
            $entries[] = [
                'type'      => 'payment',
                'date'      => $payment->created_at?->toISOString(),
                'reference' => 'Payment #'.$payment->id,
                'notes'     => $payment->notes,
                'debit'     => 0.0,
                'credit'    => round((float) $payment->amount, 2),
                'source_id' => $payment->id,
                'pdf_url'   => null,
            ];
        }

        // ── Sort by date ascending ────────────────────────────────────────
        usort($entries, fn ($a, $b) => strcmp($a['date'] ?? '', $b['date'] ?? ''));

        // ── Compute running balance ───────────────────────────────────────
        $running = 0.0;
        foreach ($entries as &$entry) {
            $running += $entry['debit'] - $entry['credit'];
            $entry['running_balance'] = round($running, 2);
        }
        unset($entry);

        // ── Summary ───────────────────────────────────────────────────────
        $totalDebit  = round(array_sum(array_column($entries, 'debit')),  2);
        $totalCredit = round(array_sum(array_column($entries, 'credit')), 2);

        return [
            'summary' => [
                'total_debit'  => $totalDebit,
                'total_credit' => $totalCredit,
                'balance'      => round($totalDebit - $totalCredit, 2),
            ],
            'ledger' => $entries,
        ];
    }
}
