<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Wraps a Client model instance that has been augmented with
 * total_debit, total_credit, and balance attributes via the
 * ClientDebitService subqueries.
 */
class ClientDebitSummaryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'uuid'         => $this->uuid,
            'contact_name' => $this->contact_name,
            'phone'        => $this->phone,
            'shop_name'    => $this->shop_name,
            'region'       => $this->region,
            'total_debit'  => (float) $this->total_debit,
            'total_credit' => (float) $this->total_credit,
            'balance'      => (float) $this->balance,
            // withTrashed() (step 06) can surface a soft-deleted client whose
            // balance is still outstanding — the UI must be able to tell them
            // apart from a live client rather than showing them identically.
            'deleted_at'   => $this->deleted_at?->toISOString(),
        ];
    }
}
