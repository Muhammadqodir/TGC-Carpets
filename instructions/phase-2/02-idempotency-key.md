# 02 — Idempotency key on label print (PROD-3)

Stop a retried print from counting a physical carpet twice. Client generates a UUID per label; server replays instead of incrementing.

**Severity:** High / **Effort:** 2 days / **Safe on live:** Yes, if `idempotency_key` is accepted as nullable during rollout — **needs a client release**

## Why this matters

`POST /production-batches/{batch}/items/{item}/print-label` increments unconditionally. There is no key, no dedupe, nothing.

The failure is not theoretical, it is the normal case on a factory floor with imperfect wifi:

1. Operator taps **Print**. `labeling_remote_datasource.dart:40` posts to the endpoint.
2. Server increments `produced_quantity` 41 → 42, commits, starts writing the response.
3. Wifi drops. The response never lands.
4. Dio raises `connectionError`; `_handleDioError` (line 50) turns it into a `NetworkException`.
5. `LabelingBloc._onPrintRequested` (`labeling_bloc.dart:35`) hits the failure branch at lines 60–67: it clears the printing flag and emits `LabelingError`. **It does not retry, and it does not reconcile with the server.**
6. The operator sees an error, sees the count still says 41 on their screen, and taps **Print** again.
7. Server increments 42 → 43.

One physical carpet, two units of production. The carpet gets one label; the database claims two. Every downstream number inherits the lie: the batch auto-completes early (`ProductionBatchService` line 172–174 checks `produced_quantity < planned_quantity - defect_quantity`), the warehouse expects a carpet that does not exist, and the owner's output report is inflated.

Note the guard at `labeling_bloc.dart:44–47` — it skips the API call if the item is already fully labeled — does **not** help. It reads the client's stale local state, which is exactly the state that never got the response.

Worth knowing: this codebase already solves this problem elsewhere. `WarehouseDocumentService::create()` (line 30–35) and `OrderService::create()` (line 20) both dedupe on an `external_uuid`. **But no client call site ever generates one** — `externalUuid` is plumbed through the Dart layers as an optional parameter and is always null in practice. So the pattern exists server-side and has never actually been used. This step is where it gets used for real; do not assume the existing plumbing works just because it compiles.

## Files to change

**Backend**

| File | Line | What is there now |
|---|---|---|
| `tgc_backend/app/Http/Controllers/Api/V1/ProductionBatchController.php` | 298–309 | `printLabel()` — no `Request`, no body, no key |
| `tgc_backend/app/Services/ProductionBatchService.php` | 164–194 | `incrementProducedQuantity()` |
| `tgc_backend/routes/api.php` | 169–170 | route definition (unchanged, listed for reference) |

**Client**

| File | Line | What is there now |
|---|---|---|
| `tgc_client/pubspec.yaml` | ~32 (`dio: ^5.7.0`) | **no `uuid` package** — must be added |
| `tgc_client/lib/features/labeling/data/datasources/labeling_remote_datasource.dart` | 10–13, 35–48 | `printLabel({batchId, itemId})`; `_dio.post(...)` at line 40 with **no body** |
| `tgc_client/lib/features/labeling/domain/repositories/labeling_repository.dart` | — | abstract `printLabel({batchId, itemId})` |
| `tgc_client/lib/features/labeling/data/repositories/labeling_repository_impl.dart` | — | passes through |
| `tgc_client/lib/features/labeling/presentation/bloc/labeling_bloc.dart` | 35–81 | `_onPrintRequested`; calls repo at line 54 |
| `tgc_client/lib/features/labeling/presentation/bloc/labeling_event.dart` | — | `LabelingPrintRequested` |

## The change

### 1. Server: accept the key, upsert on it, replay on collision

`printLabel()` currently takes no `Request`. Add one (step 01 already requires this to get `$userId`):

```php
public function printLabel(
    Request $request,
    ProductionBatch $productionBatch,
    ProductionBatchItem $item,
): JsonResponse {
    if ($item->production_batch_id !== $productionBatch->id) {
        return response()->json(['message' => 'Item does not belong to this batch.'], 404);
    }

    $validated = $request->validate([
        'idempotency_key' => ['nullable', 'uuid'],   // nullable during rollout — see below
    ]);

    $updated = $this->service->incrementProducedQuantity(
        $item,
        $request->user()->id,
        $validated['idempotency_key'] ?? null,
    );

    return response()->json(['data' => new ProductionBatchItemResource($updated)]);
}
```

**`nullable` is mandatory, not a nicety.** Old app builds in the factory send no body at all. If the rule is `required`, every one of them starts getting 422 the instant you deploy, and label printing stops. Accept null for the whole rollout window; tighten to `required` only once you have confirmed no old clients remain (see below).

In the service, do the dedupe check **inside** the transaction, on the unique index — not with a `SELECT` first, which races:

```php
public function incrementProducedQuantity(
    ProductionBatchItem $item,
    int $userId,
    ?string $idempotencyKey = null,
): ProductionBatchItem {
    DB::transaction(function () use ($item, $userId, $idempotencyKey): void {
        if ($idempotencyKey !== null) {
            try {
                ProductionEvent::create([
                    'production_batch_item_id' => $item->id,
                    'event_type'               => ProductionEvent::TYPE_PRODUCED,
                    'quantity'                 => 1,
                    'occurred_at'              => now(),
                    'user_id'                  => $userId,
                    'idempotency_key'          => $idempotencyKey,
                    'created_at'               => now(),
                ]);
            } catch (QueryException $e) {
                if ($this->isDuplicateKey($e)) {
                    return;   // replay: event already recorded, do NOT increment
                }
                throw $e;
            }
        } else {
            // Legacy client: no key. Record the event, accept the double-count risk.
            ProductionEvent::create([... 'idempotency_key' => null ...]);
        }

        $item->increment('produced_quantity');

        // ... existing batch auto-complete check, unchanged ...
    });

    return $item->fresh()->load([...]);   // unchanged
}

private function isDuplicateKey(QueryException $e): bool
{
    return $e->errorInfo[1] ?? null === 1062;   // MySQL ER_DUP_ENTRY
}
```

Three things worth being explicit about:

- **Let the unique index do the work.** `SELECT ... WHERE idempotency_key = ?` then insert has a window where two concurrent retries both see nothing and both insert. The `uniq_idem` index from step 01 is the only thing that actually serialises this.
- **Return early, do not throw.** On a replay the caller gets **200 with the current state**, not an error. The whole point is that the operator's second tap is harmless and looks identical to the first. `$item->fresh()` after the transaction returns the already-correct count, so the client's screen self-corrects to the true value — which also fixes the stale-state problem at `labeling_bloc.dart:44`.
- **Catching `QueryException` inside a transaction is safe here** because the duplicate-key insert is the first statement; MySQL rolls back the failed statement, not the transaction. Return from the closure and the transaction commits with no changes.

`nullable` on the FK column and `->unique()` in step 01's migration already permit many NULL keys (MySQL unique indexes ignore NULLs), so legacy rows coexist fine.

### 2. Client: one UUID per *physical label*, not per attempt

This is the entire correctness argument, so get it right: the key must be generated **when the operator decides to print a carpet**, and **reused unchanged** for every retry of that same carpet. If you generate it inside the retry loop, or inside the datasource, you have built nothing — each attempt gets a fresh key and still double-counts.

Add the package:

```yaml
# pubspec.yaml
dependencies:
  uuid: ^4.5.1
```

Generate in the bloc, where one user action = one carpet (`labeling_bloc.dart:35`):

```dart
Future<void> _onPrintRequested(
  LabelingPrintRequested event,
  Emitter<LabelingState> emit,
) async {
  final current = state;
  if (current is! LabelingLoaded) return;

  // ... existing isFullyLabeled guard ...

  // One key per physical label. Generated here, at the user's tap.
  final idempotencyKey = const Uuid().v4();

  emit(current.copyWith(
    printingItems: {...current.printingItems, event.itemId: true},
  ));

  final result = await _repository.printLabel(
    batchId: event.batchId,
    itemId: event.itemId,
    idempotencyKey: idempotencyKey,
  );
  // ... existing fold, unchanged ...
}
```

Thread `idempotencyKey` through `LabelingRepository`, `LabelingRepositoryImpl`, and the datasource, which currently posts with no body (line 40):

```dart
final response = await _dio.post(
  ApiEndpoints.productionBatchItemPrintLabel(batchId, itemId),
  data: {'idempotency_key': idempotencyKey},
);
```

**Optional but strongly recommended:** the operator retrying by hand is what makes the key reusable *in principle*, but nothing today carries the key across taps — the bloc generates a new one on the next tap. To close the loop properly, hold the key against the item id in `LabelingLoaded` state (or reuse the existing `printingItems` map shape) so a retry for the same item resends the same key, and only clear it once the request succeeds. Without that, this step protects against a duplicated request *in flight* (Dio retry, double-tap, app resume) but not against the operator's manual re-tap 20 seconds later. Decide explicitly which of the two you are shipping and say so in the release notes — do not let it be an accident.

### 3. Rollout order — this needs a client release

Non-negotiable sequence:

1. Deploy the **server** with `idempotency_key` nullable. Old clients keep working, byte-for-byte unchanged behaviour.
2. Ship the **client** release. Watch adoption — `app_releases` exists in this codebase, and the factory's tablets update on their own schedule, which is to say slowly.
3. Track how many old clients remain:
   ```sql
   SELECT DATE(occurred_at) AS d,
          SUM(idempotency_key IS NULL) AS legacy_writes,
          SUM(idempotency_key IS NOT NULL) AS keyed_writes
   FROM production_events
   WHERE event_type = 'produced' AND occurred_at >= NOW() - INTERVAL 14 DAY
   GROUP BY d ORDER BY d;
   ```
4. Only when `legacy_writes` has been 0 for a week should you consider `['required', 'uuid']`. There is no rush; nullable is not harmful, it just leaves old clients unprotected.

## How to verify

No test suite — verify by hand on staging.

1. **Replay is a no-op.** Fire the same key twice:
   ```bash
   KEY=$(uuidgen | tr 'A-Z' 'a-z')
   for i in 1 2; do
     curl -X POST https://<host>/api/v1/production-batches/<BATCH>/items/<ITEM>/print-label \
       -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
       -H "Accept: application/json" \
       -d "{\"idempotency_key\":\"$KEY\"}"
     echo
   done
   ```
   Both must return **200**. Then:
   ```sql
   SELECT produced_quantity FROM production_batch_items WHERE id = <ITEM>;
   SELECT COUNT(*) FROM production_events WHERE idempotency_key = '<KEY>';   -- must be 1
   ```
   The counter must have moved by **exactly 1**, not 2. Both response bodies must show the same `produced_quantity`.
2. **Distinct keys still count.** Repeat with two different UUIDs — counter moves by 2, two event rows.
3. **Legacy client still works.** Post with no body at all (simulating an old tablet):
   ```bash
   curl -X POST https://<host>/api/v1/production-batches/<BATCH>/items/<ITEM>/print-label \
     -H "Authorization: Bearer <TOKEN>" -H "Accept: application/json"
   ```
   Must return 200 and increment. Must **not** return 422.
4. **Malformed key is rejected.** Post `{"idempotency_key":"not-a-uuid"}` → 422, and confirm the counter did **not** move.
5. **The real scenario, end to end.** On a staging tablet: put the device in airplane mode mid-print (or point Dio at a host that black-holes), let it fail, restore network, tap Print again for the same carpet. Count the physical labels printed vs `produced_quantity`. They must match. *This is the test that actually matters* — if you only ran the curl checks, you have verified the server and not the fix.
6. **Concurrency.** Fire the same key 10 times in parallel (`xargs -P 10`) and confirm `COUNT(*) = 1` for that key and the counter moved by 1. This is what proves you are relying on the index, not a `SELECT`.

## Rollback

- **Server:** revert the controller and service changes. The column and index stay (harmless). Clients that send `idempotency_key` will have it silently ignored by the old code — no error, just no protection. Safe.
- **Client:** the released app keeps sending the key. If the server has been reverted, nothing breaks. There is no need to force a client downgrade, which is fortunate because you largely cannot.
- **Do not drop the `uniq_idem` index on rollback** — step 03's backfill and step 06's reconcile do not depend on it, but re-adding a unique index to a populated table on live is a locking operation you do not want to schedule twice.
- If you must fully undo: revert code first, leave schema. Schema removal belongs with step 01's rollback.

## Depends on / blocks

- **Depends on: 01** — the `idempotency_key` column and `uniq_idem` unique index are created there, and this step's dedupe is meaningless without the event row.
- **Blocks:** nothing structurally, but it directly improves the quality of the data that 04 will report on. Every double-counted label shipped before this lands is permanent, unfixable noise in the historical numbers.
- Run this **before** 04 flips analytics over if you can, so the owner's first look at event-sourced numbers is not polluted by known double-counts.
