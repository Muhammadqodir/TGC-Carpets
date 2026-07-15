# Add the missing `product_color_id` rule — warehouse document editing is 100% dead

`UpdateWarehouseDocumentRequest` doesn't declare the one key the service actually reads, so Laravel strips it and every request fails.

**Severity:** Critical · **Effort:** 10 min · **Safe on live:** Yes

**Finding:** LOGIC-2 · **Depends on:** `phase-0/02` — **do that first**, see the warning below

**Status:** ✅ Implemented 2026-07-15 — see [DEPLOY.md](DEPLOY.md) before shipping.

## ⚠️ Order matters

Fixing this endpoint **unmasks `phase-0/02`**. Right now the item-replacement branch in `WarehouseDocumentService::update()` always aborts and rolls back, which accidentally prevents the reversal-direction bug from ever executing on that path. Repair this endpoint before fixing the reversal, and you turn a dead endpoint into a live data-corruption endpoint.

**Ship `phase-0/02` first, or ship them in the same deploy.**

## Why this matters

`app/Http/Requests/WarehouseDocument/StoreWarehouseDocumentRequest.php:26` declares:

```php
'items.*.product_color_id' => ['required', 'integer', 'exists:product_colors,id'],
```

`app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php:24-30` **does not**:

```php
'items'                    => ['sometimes', 'required', 'array', 'min:1'],
'items.*.product_id'       => ['required_with:items', 'integer', 'exists:products,id'],
'items.*.product_size_id'  => ['nullable', 'integer', 'exists:product_sizes,id'],
'items.*.quantity'         => ['required_with:items', 'integer', 'min:1'],
'items.*.source_type'      => ['nullable', 'string', Rule::in(['shipment_item', 'production_batch_item'])],
'items.*.source_id'        => ['nullable', 'integer', 'min:1'],
'items.*.notes'            => ['nullable', 'string'],
// no product_color_id
```

But the service reads exactly that key, at `WarehouseDocumentService.php:137` and `:214`:

```php
$variant = $this->variantService->findOrCreate(
    $itemData['product_color_id'],          // ← never present in validated()
    $itemData['product_size_id'] ?? null,
);
```

Laravel's `Validator::validated()` excludes unvalidated array keys by default (`$excludeUnvalidatedArrayKeys = true`), and skips the parent `items` key whenever `items.*` child rules exist. So `validated()['items'][0]` contains `product_id`, `product_size_id`, `quantity`, `source_type`, `source_id`, `notes` — and **`product_color_id` is discarded**.

Both branches then fail:

- `PATCH {"type":"out","items":[…]}` → `assertSufficientStock` reads undefined `product_color_id` → `null` → `ProductVariant::where('product_color_id', null)->first()` → `null` → `$currentStock = 0` → **always** throws a bogus 422: *"Insufficient stock for 'Product color #' (). Available: 0"* — naming a product that doesn't exist.
- `PATCH {"type":"in","items":[…]}` → skips the stock check → `findOrCreate(null, …)` → **`TypeError`** (the signature is `findOrCreate(int $productColorId, ...)`) → **500**.

## The change

`app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php` — add the rule, mirroring the store request:

```php
'items.*.product_color_id' => ['required_with:items', 'integer', 'exists:product_colors,id'],
```

Use `required_with:items` rather than `required`, to stay consistent with the sibling rules in this request (the store request uses plain `required` because `items` is itself required there).

### While you're here

Two more divergences between the two requests. Both are safe to fix now:

- **`items.*.product_id` is validation theatre.** Both requests `require` it; the service never reads it. The product is derived through `product_color_id → product_colors.product_id`. Either drop it, or keep it and add a `withValidator` check that it actually matches the colour's product. Dropping is simpler and honest — but check the Flutter client still sends it before removing, since a `required` rule being relaxed never breaks a caller.
- **`items.*.product_size_id` is `required` in store but `nullable` in update.** Decide which is true. Given `product_variants.product_size_id` is nullable, `nullable` is probably right — but then the store request is wrong, and sizeless variants can't be created through it.

Don't fix the second one in this step unless you're confident; it's a behaviour change, not a crash fix. Note it and move on.

## How to verify

No test suite. By hand, against staging:

1. `PATCH /warehouse-documents/{id}` with `type: "in"` and a valid `items` array including `product_color_id` → expect **200**, not 500.
2. Same with `type: "out"` where stock is sufficient → expect **200**, not the bogus 422.
3. Same with `type: "out"` where stock is genuinely insufficient → expect a **422 naming the real product**, not `'Product color #' ()`.
4. Check the ledger afterwards:
   ```sql
   SELECT id, movement_type, quantity, notes
   FROM stock_movements
   WHERE warehouse_document_item_id IN (
       SELECT id FROM warehouse_document_items WHERE warehouse_document_id = <id>
   ) ORDER BY id;
   ```
   You should see the original movements, one compensating reversal each (from `phase-0/02`), and the new movements. Net stock must equal what the new items say.
5. Confirm the Flutter client's edit screen works end to end.

## Rollback

Revert the commit. The endpoint returns to failing 100% of the time — which, until `phase-0/02` ships, is arguably safer than working.

## Note

Nobody has been able to edit a warehouse document since this rule went missing. Worth asking the owner how staff have been working around it — the answer may reveal that they delete and recreate documents instead, which routes straight through the `phase-0/02` reversal bug and would explain existing stock drift.
