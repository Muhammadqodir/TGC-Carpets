# 03 — Fix the production batch state machine (LOGIC-4)

`planned` is a state no batch can ever be in, which makes the Start button and batch deletion unreachable code.

**Severity: Medium / Effort: 3 days / Safe on live: Yes — either path is a small, reversible change**

## Why this matters

The schema says batches start `planned`. The service says otherwise.

`tgc_backend/database/migrations/2026_04_11_000002_create_production_batches_table.php` line 19:

```php
$table->enum('status', ['planned', 'in_progress', 'completed', 'cancelled'])->default('planned');
```

`tgc_backend/app/Services/ProductionBatchService.php` `create()` (line 32), lines 35–45:

```php
$batch = ProductionBatch::create([
    'batch_title'             => $data['batch_title'],
    'planned_datetime'        => $data['planned_datetime'] ?? null,
    'machine_id'              => $data['machine_id'],
    'type'                    => $data['type'] ?? ProductionBatch::TYPE_BY_ORDER,
    'status'                  => ProductionBatch::STATUS_IN_PROGRESS,   // line 40
    'started_datetime'        => now(),                                 // line 41
    'responsible_employee_id' => $userId,
    'created_by'              => $userId,
    'notes'                   => $data['notes'] ?? null,
]);
```

The column default is never used, because `create()` always passes an explicit status. **No batch in the database has ever been `planned`.** Three things follow:

**1. `start()` is unreachable.** `ProductionBatchController::start()` (line 111), lines 113–115:

```php
if ($productionBatch->status !== ProductionBatch::STATUS_PLANNED) {
    return response()->json(['message' => 'Batch can only be started from planned status.'], 422);
}
```

Nothing is ever `planned`, so `POST /api/v1/production-batches/{id}/start` returns 422 unconditionally. It is dead code guarded by a condition that cannot be true.

**2. No batch can ever be deleted.** `ProductionBatchController::destroy()` (line 94), lines 96–101:

```php
if ($productionBatch->status !== ProductionBatch::STATUS_PLANNED) {
    return response()->json(
        ['message' => 'Only planned batches can be deleted.'],
        422,
    );
}
```

Same condition, so `DELETE /api/v1/production-batches/{id}` is 422 for every batch that has ever existed. A batch created by mistake — wrong machine, wrong order, fat-fingered quantity — cannot be removed. The only escape is `cancel`, which leaves the row in place and in every report that does not filter `cancelled`. Ask the factory how many junk batches are sitting in the list; that number is the cost of this bug.

**3. `planned_datetime` is accepted, stored, and meaningless.** Line 37 persists it. `started_datetime` is force-set to `now()` on the same insert (line 41). So a batch scheduled for next Tuesday is recorded as having started the moment someone typed it in. Any report joining on `started_datetime` is measuring data entry time, not production time.

### The client has a Start button that can never render

`tgc_client/lib/features/production/presentation/pages/production_batch_detail_page.dart`:

- line 92 — `await sl<ProductionBatchRemoteDataSource>().startBatch(...)`
- line 186 — `if (widget.batch.status == 'planned')` — the guard on the Start control
- lines 244, 303 — further `'planned'` branches
- line 347 — `'planned' => ('Rejalashtirilgan', AppColors.warning)` — a status chip that is never painted

`tgc_client/lib/core/constants/api_endpoints.dart` line 86 defines `'/production-batches/$id/start'`, and `production_batch_remote_datasource.dart` lines 47 and 224 implement `startBatch`. The entity comment at `production_batch_entity.dart` line 34 documents all four states.

So a complete scheduling feature exists on both sides of the wire and has never once executed. Somebody built it, and a single line in the service switched it off.

## Files to change

- `tgc_backend/app/Services/ProductionBatchService.php` — `create()` line 32, specifically lines 40–41
- `tgc_backend/app/Http/Controllers/Api/V1/ProductionBatchController.php` — `destroy()` line 94, `start()` line 111
- `tgc_backend/app/Models/ProductionBatch.php` — status constants lines 26–29
- `tgc_backend/routes/api.php` — the `start` route
- `tgc_client/lib/features/production/presentation/pages/production_batch_detail_page.dart` — lines 92, 186, 244, 303, 347
- `tgc_client/lib/features/production/data/datasources/production_batch_remote_datasource.dart` — lines 47, 224
- `tgc_client/lib/core/constants/api_endpoints.dart` — line 86

## The change

Decide first. Do not implement both.

### The decision

**Ask the factory one question: do you ever create a batch that is not started immediately?**

Choose **Path A (scheduling matters)** if any of these are true:
- batches are entered the day before, or in a morning planning session for the day's work
- a batch is assigned to a loom that is currently busy, to be started when it frees up
- someone wants to see "what is queued for machine 3" as distinct from "what machine 3 is running"
- the Uzbek label `Rejalashtirilgan` ("Planned") is a word the floor actually uses

Choose **Path B (it does not)** if:
- the batch is created *by* the operator *at* the loom *when* they start work, always
- nobody has ever asked why the Start button is missing — strong evidence the state is not wanted
- `planned_datetime` in existing rows is always null or always equal to the creation date

Run this before deciding — it is the empirical version of the question:

```sql
SELECT
    COUNT(*)                                                   AS total,
    SUM(planned_datetime IS NULL)                              AS no_planned_date,
    SUM(ABS(TIMESTAMPDIFF(MINUTE, planned_datetime, created_at)) <= 5) AS planned_equals_created,
    SUM(planned_datetime > DATE_ADD(created_at, INTERVAL 1 HOUR))      AS genuinely_scheduled_ahead
FROM production_batches;
```

If `genuinely_scheduled_ahead` is near zero, users have never scheduled anything and Path B is honest. If it is material, people are already trying to schedule and the software is ignoring them — Path A.

Default to **Path B** if the answer is ambiguous. Deleting an unused state is cheap and reversible; maintaining a state machine nobody uses is a permanent tax, and the current half-built version is actively harmful because it disables deletion.

---

### Path A — scheduling matters

**1. `create()` honours the request.** Replace lines 40–41:

```php
// current
'status'           => ProductionBatch::STATUS_IN_PROGRESS,
'started_datetime' => now(),

// intended
'status'           => $startNow ? ProductionBatch::STATUS_IN_PROGRESS : ProductionBatch::STATUS_PLANNED,
'started_datetime' => $startNow ? now() : null,
```

Derive `$startNow` explicitly — do not infer it from `planned_datetime` being present:

```php
$startNow = (bool) ($data['start_now'] ?? true);
```

Defaulting `start_now` to `true` preserves today's behaviour exactly for every existing client. That is what makes this safe to deploy before the client ships. Add `'start_now' => ['sometimes','boolean']` to `StoreProductionBatchRequest`.

**2. `start()` becomes reachable.** No code change needed — it starts working the moment a `planned` batch exists. Confirm `ProductionBatchService::start()` sets `started_datetime = now()` and `responsible_employee_id`; note `create()` currently sets `responsible_employee_id` to the creator (line 42), whereas `start()` takes it as required input (controller lines 117–119). For a planned batch, leave `responsible_employee_id` null at creation and let `start()` set it — the person who schedules is not the person who runs the loom, which is the entire point.

**3. `destroy()` starts working.** No change; a `planned` batch can now be deleted. Confirm `ProductionBatchService::delete()` handles the order-status side effects — `create()` moves linked orders to `on_production` at lines 60–64, and deleting a planned batch must not strand an order in that state. If a planned batch is deleted, its orders should revert to `pending`/`planned`. This is the one genuinely fiddly part of Path A; write a test for it.

**4. Do not move linked orders to `on_production` at creation for planned batches.** Lines 51–64 currently do this unconditionally. A batch scheduled for Tuesday should not claim its orders are in production on Monday. Gate that block on `$startNow`, and move it into `start()` for the planned path.

**5. Client.** The Start button at line 186 begins rendering by itself once `planned` batches exist. Add a "start now / schedule" choice to the create form. The status chip at line 347 already handles `planned`.

---

### Path B — it does not

**1. Delete the state.** Remove `STATUS_PLANNED` from `ProductionBatch.php` lines 26 and 32, and drop it from the enum:

```sql
-- no rows can be affected: no batch has ever been 'planned'
ALTER TABLE production_batches
  MODIFY COLUMN status ENUM('in_progress','completed','cancelled') NOT NULL DEFAULT 'in_progress';
```

Verify the count is zero first — it must be, but check rather than assume:

```sql
SELECT COUNT(*) FROM production_batches WHERE status = 'planned';  -- expect 0
```

**2. Delete `start()`** (controller line 111), its route, `ProductionBatchService::start()`, and the client's `startBatch` (datasource lines 47, 224) and endpoint (line 86).

**3. Fix `destroy()`.** This is the actual user-facing win of Path B — deletion must become possible. Replace the `planned` guard at lines 96–101 with a rule that is true sometimes:

```php
if ($productionBatch->status === ProductionBatch::STATUS_COMPLETED) {
    return response()->json(['message' => 'Completed batches cannot be deleted.'], 422);
}

if ($productionBatch->items()->where('produced_quantity', '>', 0)->exists()) {
    return response()->json(['message' => 'Batches with produced items cannot be deleted. Cancel it instead.'], 422);
}
```

"Nothing has been made yet" is the correct condition for deletion, and it is knowable. Once a single label is printed the batch has physical consequences and must be cancelled, not erased. After `02-production-units-serials.md`, prefer `production_units` existence over `produced_quantity > 0` — it is the honest test.

**4. Drop `planned_datetime`**, or keep the column and stop accepting it. Dropping is cleaner; if any report reads it, keep the column and remove it from the request. Check before dropping:

```bash
cd tgc_backend && grep -rn "planned_datetime" app/ resources/ routes/
```

**5. Client.** Remove the `'planned'` branches at lines 186, 244, 303, 347 and the entity comment at line 34. Leaving them is harmless but they are lies about the domain.

## How to verify

Path A:
1. Create a batch with `start_now: false`. Status is `planned`, `started_datetime` is null.
2. The Start button renders in the client for that batch — for the first time ever.
3. `POST /production-batches/{id}/start` with a `responsible_employee_id` → status `in_progress`, `started_datetime` set.
4. `DELETE` a planned batch → 200. Its linked orders revert out of `on_production`.
5. Create a batch with no `start_now` key → `in_progress`, `started_datetime = now()`. **Old clients must be unaffected.** Test with the current production client build.
6. A planned batch does not put its orders into `on_production`.

Path B:
1. `SELECT COUNT(*) FROM production_batches WHERE status='planned'` → 0 before migrating.
2. Create a batch → `in_progress`. Unchanged.
3. `DELETE` a fresh batch with nothing produced → 200, row gone.
4. `DELETE` a batch with one label printed → 422 telling you to cancel.
5. `POST /production-batches/{id}/start` → 404 (route gone).
6. The client shows no Start button and no `planned` chip.

Both: run the route smoke test from `01-tests-and-ci.md`. The batch routes must stay under 500.

## Rollback

Path A: revert the service change — `create()` goes back to forcing `in_progress`, and any `planned` batches created in the meantime need manual promotion:

```sql
UPDATE production_batches
SET status = 'in_progress', started_datetime = COALESCE(started_datetime, created_at)
WHERE status = 'planned';
```

Do this *before* redeploying the old code, or those batches become invisible to a client that no longer understands the state.

Path B: the enum migration's `down()` restores `planned`; no rows had it, so the restore is exact. The `destroy()` guard change is an ordinary revert. Deletions performed under the new rule are not recoverable — batches are hard-deleted. If that is a concern, add `SoftDeletes` to `ProductionBatch` as part of Path B and make deletion recoverable from day one. Given `06-audit-log.md` is coming, this is worth doing.

## Depends on / blocks

- **Depends on `01-tests-and-ci.md`.** Both paths touch batch creation, which every other production feature sits on.
- **Independent of Phase 2.** `production_events` does not change the analysis; if it has landed, emit an event on the `planned` → `in_progress` transition (Path A) or on deletion (Path B).
- **Interacts with `02-production-units-serials.md`.** If 02 has landed, Path B step 3 should test `production_units` rather than `produced_quantity` — the latter is inflated by reprints, so a batch with zero real carpets could report `produced_quantity > 0` and be undeletable for a bug reason. Doing 03 first is fine; just revisit the guard.
- **Blocks nothing.** This is self-contained, which is why it is only three days. Do it early — it is the cheapest visible win in Phase 3, and "we can finally delete a mistaken batch" buys goodwill for the larger items.
