# Reject a type-only PATCH on a warehouse document

Changing a document's type without replacing its items is accepted and persisted, leaving the document and the ledger permanently disagreeing.

**Severity:** Critical · **Effort:** 1 h · **Safe on live:** Yes — closes a path that only produces corruption

**Finding:** LOGIC-1 (step 2) · **Depends on:** nothing · **Related:** `phase-0/02`

## Why this matters

`app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php:19` allows `type` to change independently of `items`:

```php
'type'  => ['sometimes', 'required', 'string', Rule::in(WarehouseDocument::TYPES)],
'items' => ['sometimes', 'required', 'array', 'min:1'],
```

And `app/Services/WarehouseDocumentService.php:66` persists it immediately, while all ledger work sits behind a check for `items`:

```php
$document->update(array_filter([
    'type' => $data['type'] ?? $document->type,     // ← always persisted
    ...
]));

if (! empty($data['items'])) {                      // ← line 73, ledger work ONLY happens here
    ...
    $this->reverseMovements($document, $userId);
    $document->items()->delete();
    $this->syncItems($document->fresh(), $data['items'], $userId);
}
```

So `PATCH /warehouse-documents/42 {"type":"out"}` flips an incoming document to outgoing and **never touches a single stock movement**.

### Failure scenario

Document #42 is `in` for 100 units.

1. `PATCH {"type":"out"}` → 200 OK.
2. `GET /warehouse-documents/42` now reports an **outgoing** document for 100 units.
3. `GET /stock` still reports **+100** — the ledger never changed.
4. The PDF regenerated at line 89–91 renders an outgoing document (`WarehousePdfService` branches on `isOutgoing()`) for movements that *added* stock. That PDF may be printed and filed.
5. Later, `DELETE` reverses in the wrong direction — see `phase-0/02`.

The document, the ledger, and the printed paperwork now tell three different stories.

## The change

A document's type determines what its movements mean. Changing it without re-issuing those movements is never valid. Two acceptable options:

**Option A (recommended) — reject it.** In `UpdateWarehouseDocumentRequest`, require `items` whenever `type` is present:

```php
'type'  => ['sometimes', 'required', 'string', Rule::in(WarehouseDocument::TYPES), 'required_with:items'],
'items' => ['sometimes', 'required', 'array', 'min:1', 'required_with:type'],
```

`required_with` alone is not enough to express "these two travel together", so add a `withValidator` that fails clearly:

```php
public function withValidator($validator): void
{
    $validator->after(function ($validator) {
        if ($this->has('type') && ! $this->has('items')) {
            $validator->errors()->add(
                'type',
                'Hujjat turini o\'zgartirish uchun mahsulotlar ro\'yxati ham yuborilishi kerak.'
            );
        }
    });
}
```

Match the existing Uzbek error-message style used in `StoreDefectDocumentRequest::messages()`.

**Option B — forbid type changes entirely.** Arguably more honest: a document that was a receipt is not later a dispatch; the correct action is to delete it and create the right one. If the client UI has no "change type" control, do this instead — it's simpler and removes the whole class of bug.

Check the Flutter client before choosing:

```bash
grep -rn "warehouse-documents" tgc_client/lib --include='*.dart' | grep -i "patch\|put\|update"
```

If nothing sends `type` on update, take Option B.

## Note on the items branch

You may notice `if (! empty($data['items']))` also silently skips ledger work when `items` is an empty array. With the validation above (`'min:1'` plus the pairing rule) that becomes unreachable, but it is worth changing to `isset($data['items'])` so intent is explicit.

Also note: that branch is currently **dead** for a different reason — see `phase-0/04`. Fix `phase-0/02` before `phase-0/04`, or repairing it will expose the reversal bug.

## How to verify

1. `PATCH /warehouse-documents/{id}` with only `{"type":"out"}` → expect **422** with a readable message (Option A) or 422/405 (Option B).
2. `PATCH` with `{"type":"out","items":[...]}` → expect it to work once `phase-0/04` lands. Until then it will still fail — that is expected and is a different bug.
3. `PATCH` with only `{"notes":"..."}` or `{"document_date":"..."}` → must still succeed. Do not break header-only edits.
4. Confirm no existing client screen has started returning 422:
   ```bash
   grep -rn "warehouse-documents" tgc_client/lib --include='*.dart'
   ```

## Rollback

Revert the commit. The endpoint returns to accepting type-only PATCHes, i.e. the current broken state.

## Data already affected

Find documents whose type disagrees with their own ledger rows — these are the ones that took this path:

```sql
SELECT wd.id, wd.type AS document_type,
       SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE -sm.quantity END) AS ledger_net
FROM warehouse_documents wd
JOIN warehouse_document_items wdi ON wdi.warehouse_document_id = wd.id
JOIN stock_movements sm ON sm.warehouse_document_item_id = wdi.id
GROUP BY wd.id, wd.type
HAVING (wd.type = 'out' AND ledger_net > 0)
    OR (wd.type IN ('in','return','adjustment') AND ledger_net < 0);
```

Any rows returned are documents already corrupted by this bug. Report the list to the owner rather than auto-correcting — each one needs a human decision about which version is true.
