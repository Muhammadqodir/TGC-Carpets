# 06 — Audit log

There is no answer to "who changed this". Add one append-only table covering every money and stock mutation.

**Severity: High / Effort: 1 week / Safe on live: Yes — additive; observers write to a new table and change no existing behaviour**

## Why this matters

A carpet factory's ERP is a record of who owes whom what. Right now it cannot tell you who wrote any of it.

Concretely, today:

- A client's debit is 12,000 USD. Last week it was 8,000. Nobody can say which shipment, which price, or which user moved it.
- A payment is recorded, then deleted. `DELETE /api/v1/payments/{payment}` exists and `Payment` has **no `SoftDeletes`** — verified: `grep -n "SoftDeletes" app/Models/Payment.php` returns nothing, and `2026_04_15_000001_create_payments_table.php` has `timestamps()` but no `deleted_at`. The row is gone. The money it represented is gone from the ledger with no trace it ever existed. There is no way to distinguish "the client never paid" from "someone deleted the payment".
- A variant's stock is 480 and should be 500. Twelve warehouse documents touched it. Which one, and who filed it? Unanswerable without reading raw rows and guessing from `user_id` on the documents that happen to carry one.

And the access control that would at least narrow the suspect list is not switched on. `EnsureRole` exists (`app/Http/Middleware/EnsureRole.php`) and is registered in `bootstrap/app.php` line 17:

```php
'role'      => \App\Http\Middleware\EnsureRole::class,
```

with the comment on line 15 — "used as 'role:admin', 'role:admin,warehouse', etc." — describing usage that does not exist. Grep `routes/` for `role:`: **zero routes use it**. Every one of the 124 API routes is available to every authenticated user. Any label operator can delete a payment, file an adjustment that mints 10,000 carpets (see `05-signed-adjustment-documents.md`), or change a price.

Phase 1 fixes both of those (applies `EnsureRole`, adds `SoftDeletes` to `Payment`). This file assumes that and adds the missing third piece: knowing *what happened*, not just who was allowed to do it.

The scenario that justifies the week: a client disputes an invoice. They say they were quoted 11 USD/m², the invoice says 13. Both numbers were typed by a human into `shipment_items.price` at different times. With an audit log this is a thirty-second query. Without it, it is the factory's word against the client's, and the factory has no evidence — including no evidence when the factory is *right*.

## Files to change

- new migration `tgc_backend/database/migrations/xxxx_create_audit_log_table.php`
- new `tgc_backend/app/Models/AuditLog.php`
- new `tgc_backend/app/Observers/AuditableObserver.php` (or a package — see below)
- new `tgc_backend/app/Concerns/Auditable.php` trait
- `tgc_backend/app/Providers/AppServiceProvider.php` — observer registration
- new `tgc_backend/app/Http/Middleware/AssignRequestId.php`
- `tgc_backend/bootstrap/app.php` — register the middleware (line 15 area, where `role` is registered)
- models to audit: `Payment`, `Shipment`, `ShipmentItem`, `WarehouseDocument`, `WarehouseDocumentItem`, `StockMovement`, `Order`, `OrderItem`, `ProductionBatch`, `ProductionBatchItem`, `DefectDocument`, `DefectDocumentItem`

## The change

### 1. The table

```sql
CREATE TABLE audit_log (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    auditable_type VARCHAR(191) NOT NULL,
    auditable_id BIGINT UNSIGNED NOT NULL,
    event ENUM('created','updated','deleted','restored') NOT NULL,
    user_id BIGINT UNSIGNED NULL,
    old_values JSON NULL,
    new_values JSON NULL,
    request_id CHAR(36) NULL,
    ip_address VARCHAR(45) NULL,
    url VARCHAR(500) NULL,
    created_at DATETIME NOT NULL,

    KEY idx_auditable (auditable_type, auditable_id, created_at),
    KEY idx_user (user_id, created_at),
    KEY idx_request (request_id)
);
```

Notes on the choices:

- **`created_at` only, no `updated_at`.** An audit row is never updated. The absence of the column is the design saying so.
- **No foreign key on `user_id`.** If a user is ever deleted, the audit row must survive. A `restrictOnDelete` FK would block user deletion; a `cascadeOnDelete` would erase history. Neither is acceptable, so keep it a bare column and resolve the name at read time. This is the one place in the schema where a missing FK is deliberate — comment it in the migration or someone will "fix" it.
- **No FK on `auditable_id`** either; it is polymorphic and the target may be hard-deleted.
- **`old_values` / `new_values` as JSON**, holding only the changed attributes, not the whole model. Full snapshots on `StockMovement` would multiply the table size for no benefit.
- **`request_id`** ties every row written by one HTTP request together. This is what turns a pile of rows into a story: one shipment save writes a `Shipment`, five `ShipmentItem`s and five `StockMovement`s, and the request id is what says they were one act by one person at one moment. It is the highest-value column here and the one most often left out.
- **`VARCHAR(191)`** on `auditable_type` for the classic MySQL utf8mb4 index-length limit. If the deployment is on utf8mb4 with a 3072-byte limit this can be longer, but 191 costs nothing.
- **`ip_address VARCHAR(45)`** fits IPv6.

### 2. What must not be lost — the append-only property

This is the part that makes it an audit log rather than a table of guesses. Be explicit, because every one of these will be violated by someone trying to be helpful:

- **Never `UPDATE` a row in `audit_log`. Never `DELETE` one.** Not to fix a typo, not to redact, not to "clean up test data". A log that can be edited is not evidence, and its value is entirely in the fact that it cannot be.
- **Never `SoftDeletes` on `AuditLog`.** A soft-deletable audit row is a contradiction.
- **The application's DB user should not hold `UPDATE`/`DELETE` on this table.** Grant `INSERT` and `SELECT` only. This is a one-line grant that converts a convention into a guarantee, and it is the single most valuable thing in this file:

  ```sql
  REVOKE UPDATE, DELETE ON tgc.audit_log FROM 'tgc_app'@'%';
  GRANT INSERT, SELECT ON tgc.audit_log TO 'tgc_app'@'%';
  ```

  Confirm the actual DB user and schema names on the server first. If migrations run as the same user, the grant must be applied after the table is created, and future migrations touching this table will fail — which is correct, and worth the inconvenience.
- **The audit write must not be able to fail silently.** If it throws, the transaction should roll back with the business change. An audit log that drops rows under load is worse than none, because it will be trusted.
- **But it must also not be the reason a shipment cannot be saved.** These two pull against each other. Resolve it explicitly: write synchronously inside the same transaction (correct, and a failure means a real bug), and do **not** queue it. `QUEUE_CONNECTION` is `sync` in testing and the app is small; async audit means a crash loses the log precisely when something is going wrong.
- **Retention: none, for now.** Do not add a pruning job. When the table gets large, archive by copying to cold storage and only then delete — and make that a deliberate, documented act, not a scheduled command someone forgets is running.

### 3. Observers, not a package

Use Laravel model observers. The candidate packages (`owen-it/laravel-auditing`, `spatie/laravel-activitylog`) are both reasonable and both bring more than is needed here: config surface, their own migrations, opinions about presentation, and an upgrade obligation on a live system with no tests. The whole mechanism is about sixty lines:

```php
class AuditableObserver
{
    public function created(Model $model): void  { $this->log($model, 'created'); }
    public function updated(Model $model): void  { $this->log($model, 'updated'); }
    public function deleted(Model $model): void  { $this->log($model, 'deleted'); }
    public function restored(Model $model): void { $this->log($model, 'restored'); }

    private function log(Model $model, string $event): void
    {
        $changes = $model->getChanges();
        unset($changes['updated_at']);

        if ($event === 'updated' && $changes === []) {
            return; // a touch with no real change is not worth a row
        }

        AuditLog::create([
            'auditable_type' => $model::class,
            'auditable_id'   => $model->getKey(),
            'event'          => $event,
            'user_id'        => auth()->id(),
            'old_values'     => $event === 'created' ? null : Arr::only($model->getOriginal(), array_keys($changes)),
            'new_values'     => $event === 'deleted' ? null : $changes,
            'request_id'     => request()->attributes->get('request_id'),
            'ip_address'     => request()->ip(),
            'url'            => Str::limit(request()->fullUrl(), 500, ''),
            'created_at'     => now(),
        ]);
    }
}
```

If you later outgrow this, swapping in a package is easy because the table is yours. Going the other way is not.

Register per model rather than globally — auditing everything means auditing `product_colors` lookups and drowning the signal:

```php
// AppServiceProvider::boot()
foreach ([
    Payment::class, Shipment::class, ShipmentItem::class,
    WarehouseDocument::class, WarehouseDocumentItem::class, StockMovement::class,
    Order::class, OrderItem::class,
    ProductionBatch::class, ProductionBatchItem::class,
    DefectDocument::class, DefectDocumentItem::class,
] as $model) {
    $model::observe(AuditableObserver::class);
}
```

Two cautions that will bite:

- **`Model::observe` does not fire on query-builder writes.** `$batch->items()->delete()` (`ProductionBatchService::update()` line 87) and `Model::whereIn(...)->update(...)` (`ProductionBatchService::create()` lines 61–63) bypass Eloquent events entirely. Those two callsites will produce no audit rows. Either convert them to per-model operations or accept and document the gap. Do not assume observers cover everything — grep for `->update([` and `->delete()` on query builders across `app/Services/` and check each.
- **`getChanges()` on `deleted` is empty**, hence `old_values` from `getOriginal()`. For a hard delete the original *is* the record, so consider storing the full attribute set on `deleted` — it is the only chance to keep it. This matters most for `Payment`, which is hard-deleted today.

### 4. Request id

```php
class AssignRequestId
{
    public function handle(Request $request, Closure $next)
    {
        $id = (string) Str::uuid();
        $request->attributes->set('request_id', $id);
        Log::withContext(['request_id' => $id]);

        return $next($request)->header('X-Request-Id', $id);
    }
}
```

Append to the global API middleware in `bootstrap/app.php`. Returning it as a header means a user reporting a problem can hand you the exact id, and `Log::withContext` ties the application log to the audit log for the same request. Both are nearly free here and expensive to retrofit.

### 5. Reading it

One endpoint is enough: `GET /api/v1/audit-log?auditable_type=&auditable_id=&user_id=&request_id=&from=&to=`, admin-only via `EnsureRole` (Phase 1). Return the diff, the user's name, and the timestamp. Do not build a UI in this pass — the first consumer is a developer answering a dispute, and a JSON endpoint serves that. Add the client view when someone asks twice.

### 6. Keep it cheap — what this is not

This is **not** event sourcing. State stays in the business tables; the audit log is a side record, and nothing rebuilds state from it. Do not:

- make anything read from `audit_log` to compute a balance
- audit `GET`s or reads
- audit lookup tables (colours, sizes, types, qualities, edges, machines)
- add versioning, or the ability to revert a model to a previous state — that is a different feature with a different budget
- store full model snapshots on every update

The Phase 2 `production_events` ledger is a different thing and both should exist. `production_events` is a **domain** ledger: it carries business meaning, is read to compute `produced_quantity`, and its entries are facts about production. `audit_log` is a **technical** record: it carries no business meaning, is read only by humans investigating, and its entries are facts about *the software being used*. Do not merge them, and do not let `audit_log` become load-bearing — the moment a balance depends on it, you cannot archive it and you have accidentally built event sourcing.

## How to verify

1. Create a payment → one `audit_log` row, `event = 'created'`, correct `user_id`, `new_values` containing `amount`.
2. Update a shipment item's price 13.00 → 11.00 → `old_values = {"price":"13.00"}`, `new_values = {"price":"11.00"}`. This is the dispute scenario; run it literally.
3. Delete a payment → a row survives with the full original values, **including after Phase 1's `SoftDeletes` lands** (a soft delete fires `deleted`, so this keeps working).
4. Save a shipment with five lines → the `Shipment`, `ShipmentItem` and `StockMovement` rows all share one `request_id`. Query by that id and read the whole act.
5. `X-Request-Id` appears on every API response and matches the audit rows.
6. Attempt `UPDATE audit_log SET user_id = 1 WHERE id = 1` as the application DB user → permission denied. If it succeeds, the grant is not applied and the log is not evidence.
7. Force the audit write to throw (rename the table in a scratch environment) → the business transaction rolls back rather than committing unlogged.
8. `ProductionBatchService::update()` line 87 (`$batch->items()->delete()`) → confirm whether rows appear. They will not. Confirm this is the documented, accepted gap and not a surprise.
9. Check write latency on a 500-line shipment. Audit adds one insert per model write; if that is material, the fix is batching inserts, not queueing them.
10. Route smoke test from `01-tests-and-ci.md` stays green — the observers touch every write path in the app.

## Rollback

Fully additive. To disable, remove the `observe()` loop in `AppServiceProvider` — the table stays and keeps its history. To remove entirely, drop the table and the middleware. No existing behaviour changes, so there is nothing to reverse in the business data.

The one irreversible act is the `REVOKE`: if migrations run as the application user, they can no longer alter this table. Re-grant temporarily if the schema must change, then revoke again, and treat any such change as an event worth recording elsewhere.

## Depends on / blocks

- **Depends on Phase 1** for `EnsureRole` actually being applied to routes (otherwise the audit log records that "some authenticated user" did it, which is a fraction of the value) and for `SoftDeletes` on `Payment` (otherwise hard deletes are audited but the row itself is unrecoverable — the log tells you what was lost without letting you restore it).
- **Depends on `01-tests-and-ci.md`.** Observers fire on every write in the application; the smoke test is what tells you none of them broke.
- **Independent of Phase 2.** If `production_events` has landed, do not audit it — it is already append-only and immutable, and auditing an audit-like table is noise.
- **Supports `04-currency-vat-discount.md`** (who changed a price, who granted a discount) and **`05-signed-adjustment-documents.md`** (who filed the adjustment that moved 10,000 carpets). Both are far more defensible with this in place. Either order works, but if 05 ships first, treat this as the follow-up that closes it.
- **Blocks nothing.** Can be done in parallel with anything else in Phase 3.
