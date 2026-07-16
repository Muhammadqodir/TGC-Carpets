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
        // For m² products: price × (width × length × quantity / 10 000)
        // For piece products: price × quantity
        // minus si.discount_amount — the frozen, per-line discount from
        // instructions/phase-3/04-currency-vat-discount.md. Defaults to
        // 0.00 for every row that predates that column, so this SUM is
        // byte-identical to before for all existing data.
        //
        // Rounded per line, inside the SUM, before aggregating — this must stay
        // in lockstep with ShipmentItem::lineTotal(). Dividing by 10000 (not
        // 10000.0) keeps DECIMAL arithmetic all the way through so MySQL's
        // ROUND() rounds half-away-from-zero, matching lineTotal()'s round2().
        // See ShipmentItem::lineTotal() — the two are a knowing duplication;
        // phase-2's balance table removes it for good.
        //
        // NOT yet VAT-aware: shipments.vat_amount is a per-shipment (not
        // per-line) figure, and this subquery aggregates at the line level —
        // summing vat_amount here would multiply-count it once per line on
        // any multi-line shipment. Since vat_rate is 0 for every shipment
        // today (no client sends a non-zero rate yet — see the instruction
        // file), this is a documented, safe-for-now gap, not a live bug.
        // Fixing it properly needs a shipment-level pre-aggregation before
        // this join, which is a bigger change than this pass — do it before
        // any shipment is created with a non-zero vat_rate.
        $debitSub = DB::table('shipment_items as si')
            ->join('shipments as s',            's.id',  '=', 'si.shipment_id')
            ->join('product_variants as pv',    'pv.id', '=', 'si.product_variant_id')
            ->join('product_colors as pc',      'pc.id', '=', 'pv.product_color_id')
            ->join('products as p',             'p.id',  '=', 'pc.product_id')
            ->leftJoin('product_sizes as ps',   'ps.id', '=', 'pv.product_size_id')
            ->select(
                's.client_id',
                DB::raw("
                    SUM(
                        ROUND(
                            CASE
                                WHEN p.unit = 'm2' AND ps.id IS NOT NULL
                                    THEN si.price * ps.length * ps.width * si.quantity / 10000
                                ELSE
                                    si.quantity * si.price
                            END,
                            2
                        ) - si.discount_amount
                    ) AS total_debit
                ")
            )
            ->groupBy('s.client_id');

        // Subquery: sum payments per client.
        // whereNull('deleted_at') because this is DB::table(), not Payment::query() —
        // the SoftDeletes global scope does not reach a raw query builder call.
        $creditSub = DB::table('payments')
            ->whereNull('deleted_at')
            ->select('client_id', DB::raw('SUM(amount) AS total_credit'))
            ->groupBy('client_id');

        // Soft-deleted clients can still owe money: their shipments and the
        // receivable are untouched by deleting the client record. A debit
        // report that hides them is worse than useless. withTrashed() brings
        // them back; the `when` below hides zero-balance deleted clients by
        // default (noise) while a deleted client who still owes always shows.
        return Client::withTrashed()
            ->leftJoinSub($debitSub, 'dbt', fn ($j) => $j->on('clients.id', '=', 'dbt.client_id'))
            ->leftJoinSub($creditSub, 'crd', fn ($j) => $j->on('clients.id', '=', 'crd.client_id'))
            ->select([
                'clients.*',
                DB::raw('COALESCE(dbt.total_debit,  0) AS total_debit'),
                DB::raw('COALESCE(crd.total_credit, 0) AS total_credit'),
                DB::raw('COALESCE(dbt.total_debit, 0) - COALESCE(crd.total_credit, 0) AS balance'),
            ])
            ->when(
                empty($filters['include_deleted']),
                fn ($q) => $q->where(fn ($q2) => $q2->whereNull('clients.deleted_at')
                    ->orWhereRaw('COALESCE(dbt.total_debit, 0) - COALESCE(crd.total_credit, 0) > 0'))
            )
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
                'items.variant.productSize',
                'items.variant.productEdge',
            ])
            ->where('client_id', $client->id)
            ->orderBy('shipment_datetime')
            ->get();

        $entries = [];

        foreach ($shipments as $shipment) {
            // Sum of already-rounded line totals — matches the invoice, because
            // the client is billed the sum of the printed line totals.
            $total = '0.00';
            foreach ($shipment->items as $item) {
                $total = bcadd($total, $item->lineTotal(), 2);
            }

            $entries[] = [
                'type'      => 'shipment',
                'date'      => $shipment->shipment_datetime?->toISOString(),
                'reference' => 'Hisob faktura #'.$shipment->id,
                'notes'     => $shipment->notes,
                'debit'     => $total,
                'credit'    => '0.00',
                'source_id' => $shipment->id,
                'pdf_url'   => $shipment->invoice_path
                    ? Storage::disk('public')->url($shipment->invoice_path)
                    : null,
            ];
        }

        // ── Collect payment entries ───────────────────────────────────────
        // Payment::where(...) applies the SoftDeletes global scope, so a
        // voided payment (step 06) is correctly excluded here.
        $payments = Payment::where('client_id', $client->id)
            ->orderBy('created_at')
            ->get();

        foreach ($payments as $payment) {
            $entries[] = [
                'type'      => 'payment',
                'date'      => $payment->created_at?->toISOString(),
                'reference' => 'To\'lov #'.$payment->id,
                'notes'     => $payment->notes,
                'debit'     => '0.00',
                'credit'    => (string) $payment->getRawOriginal('amount'),
                'source_id' => $payment->id,
                'pdf_url'   => null,
            ];
        }

        // ── Sort by date ascending ────────────────────────────────────────
        usort($entries, fn ($a, $b) => strcmp($a['date'] ?? '', $b['date'] ?? ''));

        // ── Compute running balance ───────────────────────────────────────
        $running = '0.00';
        foreach ($entries as &$entry) {
            $running = bcadd(bcsub($running, $entry['credit'], 2), $entry['debit'], 2);
            $entry['running_balance'] = $running;
        }
        unset($entry);

        // ── Summary ───────────────────────────────────────────────────────
        $totalDebit  = array_reduce($entries, fn ($carry, $e) => bcadd($carry, $e['debit'], 2), '0.00');
        $totalCredit = array_reduce($entries, fn ($carry, $e) => bcadd($carry, $e['credit'], 2), '0.00');

        return [
            'summary' => [
                'total_debit'  => $totalDebit,
                'total_credit' => $totalCredit,
                'balance'      => bcsub($totalDebit, $totalCredit, 2),
            ],
            'ledger' => $entries,
        ];
    }
}
