# 01 — The `production_events` table

Create an append-only event log for production quantities, and dual-write to it from every path that currently moves a counter. Nothing reads it yet.

**Severity:** High (foundation for all of phase 2) / **Effort:** 4 days / **Safe on live:** Yes — purely additive, no existing reader changes

## Why this matters

`production_batch_items.produced_quantity` is a running total with no history behind it. Today, printing a label runs exactly this (`app/Services/ProductionBatchService.php:167`):

```php
$item->increment('produced_quantity');
```

That is the entire record of a carpet being made. The row goes from 41 to 42 and the system has no idea who printed it, when, or on which shift. If the number is wrong there is nothing to compare it against — no way to answer "should this be 42?" because the only evidence *is* the 42.

Concrete failure: an item shows `produced_quantity = 500`. The owner asks how many were woven on 6 January. Nobody can answer, not even in principle. The data was never recorded. Every other problem in this phase (analytics on the wrong date, double-counted labels, phantom defects) is a symptom of this single missing table.

The rule this phase is built on: **a quantity that changes over time is an event log; any column holding a total is a cache of that log and must be reconcilable against it.** Right now there is a cache with no log.

`produced_quantity` **stays exactly where it is**, written in the same transaction as the event. That is what makes this deploy non-breaking — every existing reader (`ProductionBatchItemResource`, the labeling list, the warehouse FIFO credit, analytics) keeps working untouched. The log is added underneath, and step 06 adds a nightly command that asserts the two agree.

## Files to change

| File | Line | What is there now |
|---|---|---|
| `tgc_backend/database/migrations/` | new | Migration to create `production_events` |
| `tgc_backend/app/Models/ProductionEvent.php` | new | Model |
| `tgc_backend/app/Services/ProductionBatchService.php` | 164–194 | `incrementProducedQuantity()`; the bare `increment()` is line 167 |
| `tgc_backend/app/Http/Controllers/Api/V1/ProductionBatchController.php` | 298–309 | `printLabel()`; calls the service at line 306 |
| `tgc_backend/app/Http/Controllers/Api/V1/DefectDocumentController.php` | 56–57 | `ProductionBatchItem::where(...)->increment('defect_quantity', ...)` |

Verified context: Laravel `^13.0`, PHP `^8.3`. `production_batch_items.produced_quantity` and `defect_quantity` are **`unsignedInteger`** (`database/migrations/2026_04_11_000003_create_production_batch_items_table.php`) — they cannot go negative; a decrement past zero will throw. That matters in step 05, not here.

## The change

### 1. Migration

```php
Schema::create('production_events', function (Blueprint $table): void {
    $table->id();
    $table->foreignId('production_batch_item_id')
          ->constrained('production_batch_items')
          ->cascadeOnDelete();
    $table->enum('event_type', ['produced', 'defect', 'scrap', 'correction']);
    $table->integer('quantity');            // signed: +1 label, -1 correction
    $table->dateTime('occurred_at');        // real business time; nothing else writes it
    $table->foreignId('user_id')->constrained('users');
    $table->char('idempotency_key', 36)->nullable()->unique('uniq_idem');
    $table->string('reason', 255)->nullable();   // required for correction/scrap
    $table->timestamp('created_at')->nullable();

    $table->index(['production_batch_item_id', 'occurred_at'], 'idx_item_time');
    $table->index('occurred_at', 'idx_time');
});
```

Note `$table->timestamp('created_at')` only — there is no `updated_at`, because rows are never updated. Set `public $timestamps = false;` and write `created_at` manually, or set `const UPDATED_AT = null;` on the model.

**`cascadeOnDelete` is deliberate — read this before changing it.** `production_batch_items` rows are **hard-deleted** on two live paths:

- `ProductionBatchService::update()` line 87 — `$batch->items()->delete();` then re-syncs. `UpdateProductionBatchRequest` puts **no status restriction** on `items`, so this fires for `in_progress` batches that already have events.
- `ProductionBatchService::delete()` line 227 — same call (though `ProductionBatchController::destroy()` line 96 restricts this to `planned` batches).

With the FK default (`RESTRICT`), both paths would start throwing a foreign-key violation in production the moment an item has one event. `cascadeOnDelete` preserves today's behaviour exactly. The honest trade-off: a strictly append-only ledger should not lose rows, but blocking a live write path is worse, and reconcile (step 06) stays correct because the item and its events disappear together. That `update()` silently destroys production history is a real bug — it is out of scope here; log it separately.

### 2. Event type → cache mapping (canonical; steps 05 and 06 depend on it)

Each event type feeds exactly **one** counter. Keep this mapping unambiguous — it is what makes reconcile a plain `GROUP BY`.

| `event_type` | Feeds | Sign | Written by |
|---|---|---|---|
| `produced` | `produced_quantity` | `+n` | label print |
| `scrap` | `produced_quantity` | `-n` only | condemning an already-produced unit (step 05) |
| `correction` | `produced_quantity` | signed | manual fix (step 05) |
| `defect` | `defect_quantity` | signed (`+n` on create, `-n` to reverse) | defect document create/delete |

So:

- `produced_quantity == SUM(quantity) WHERE event_type IN ('produced','scrap','correction')`
- `defect_quantity   == SUM(quantity) WHERE event_type = 'defect'`

A deviation worth flagging: a defect-document deletion is reversed with a **negative `defect` row**, not a `correction` row, because `correction` is reserved for `produced_quantity` above. It is still a reversing entry — the append-only principle holds. Step 05 covers this.

### 3. Model

`app/Models/ProductionEvent.php`:

```php
class ProductionEvent extends Model
{
    const UPDATED_AT = null;   // append-only: rows are never updated

    const TYPE_PRODUCED   = 'produced';
    const TYPE_DEFECT     = 'defect';
    const TYPE_SCRAP      = 'scrap';
    const TYPE_CORRECTION = 'correction';

    protected $fillable = [
        'production_batch_item_id', 'event_type', 'quantity',
        'occurred_at', 'user_id', 'idempotency_key', 'reason',
    ];

    protected function casts(): array
    {
        return [
            'quantity'    => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public function productionBatchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
```

### 4. Dual-write from the label print path

`incrementProducedQuantity()` (line 164) already opens a `DB::transaction` at line 166 — put the event write inside it, next to the counter. Both succeed or both roll back; that invariant is the whole point.

The method currently takes only `ProductionBatchItem $item` and the controller has the `Request`. You need the acting user, so change the signature to accept `int $userId` and pass `$request->user()->id` from `printLabel()`. That means `printLabel()` (line 298) must take a `Request $request` as its first parameter — it does not today.

Current (lines 164–183, abridged):

```php
public function incrementProducedQuantity(ProductionBatchItem $item): ProductionBatchItem
{
    DB::transaction(function () use ($item): void {
        $item->increment('produced_quantity');
        // ... batch auto-complete check ...
    });
    // ...
}
```

Intended:

```php
public function incrementProducedQuantity(ProductionBatchItem $item, int $userId): ProductionBatchItem
{
    DB::transaction(function () use ($item, $userId): void {
        ProductionEvent::create([
            'production_batch_item_id' => $item->id,
            'event_type'               => ProductionEvent::TYPE_PRODUCED,
            'quantity'                 => 1,
            'occurred_at'              => now(),
            'user_id'                  => $userId,
            'idempotency_key'          => null,   // step 02 fills this
            'reason'                   => null,
            'created_at'               => now(),
        ]);

        $item->increment('produced_quantity');

        // ... existing batch auto-complete check, unchanged ...
    });
    // ... existing fresh()->load(...), unchanged ...
}
```

Leave the auto-complete block (lines 169–182) exactly as it is. Do not touch the returned resource.

`occurred_at` is `now()` here and that is correct — the label is printed at the moment the carpet is finished. It is set once, at insert, and **nothing ever updates it**. That property is what step 04 relies on.

### 5. Dual-write from the defect path

`DefectDocumentController::store()` already runs inside `DB::transaction` (line 41). The loop at lines 49–58 creates a `DefectDocumentItem` and increments `defect_quantity`. Add the event in the same loop:

```php
foreach ($request->input('items', []) as $itemData) {
    DefectDocumentItem::create([...]);   // unchanged

    ProductionEvent::create([
        'production_batch_item_id' => $itemData['production_batch_item_id'],
        'event_type'               => ProductionEvent::TYPE_DEFECT,
        'quantity'                 => (int) $itemData['quantity'],   // positive
        'occurred_at'              => $document->datetime,
        'user_id'                  => $request->user()->id,
        'reason'                   => $request->input('description'),
        'created_at'               => now(),
    ]);

    ProductionBatchItem::where('id', $itemData['production_batch_item_id'])
        ->increment('defect_quantity', $itemData['quantity']);   // unchanged
}
```

Use `$document->datetime` (not `now()`) for `occurred_at` — the store method already honours a client-supplied `datetime` at line 45, so the operator can record a defect found yesterday. That is real business time, which is exactly what the column is for.

Leave `destroy()` (line 94) alone in this step. It is broken — it never decrements `defect_quantity` — but fixing it is step 05.

## How to verify

There is no test suite. Do this by hand on staging, then repeat the read-only checks on live after deploy.

1. Migrate, then confirm the table and indexes exist:
   ```sql
   SHOW CREATE TABLE production_events\G
   ```
2. Pick an in-progress batch item and note its current counter:
   ```sql
   SELECT id, produced_quantity, defect_quantity FROM production_batch_items WHERE id = <ID>;
   ```
3. Print a label from the Flutter app (Labeling page → tap Print), or:
   ```bash
   curl -X POST https://<host>/api/v1/production-batches/<BATCH>/items/<ITEM>/print-label \
     -H "Authorization: Bearer <TOKEN>" -H "Accept: application/json"
   ```
4. Confirm both sides moved together:
   ```sql
   SELECT produced_quantity FROM production_batch_items WHERE id = <ITEM>;
   SELECT * FROM production_events WHERE production_batch_item_id = <ITEM> ORDER BY id DESC LIMIT 5;
   ```
   `produced_quantity` must be up by 1 **and** there must be exactly one new `produced` row with `quantity = 1`, a sane `occurred_at`, and the correct `user_id`.
5. The response body must be byte-for-byte what it was before. Compare against a saved response from before deploy — no new fields, no missing fields.
6. Create a defect document from the app for a batch item. Confirm `defect_quantity` moved and exactly one `defect` row appeared with `occurred_at` matching the document's `datetime`.
7. Force a rollback to prove atomicity: temporarily `throw new \RuntimeException('x');` at the end of the transaction closure in `incrementProducedQuantity`, print a label, confirm **neither** the counter nor an event moved. Remove the throw.
8. Regression check on the FK cascade — this is the risky one:
   - Take a staging batch that is `in_progress` and has printed labels (so its items have events).
   - `PATCH /api/v1/production-batches/<BATCH>` with an `items` array (this hits `ProductionBatchService::update()` line 87).
   - It must return 200, not a foreign-key error. Confirm the old items' events are gone rather than orphaned:
     ```sql
     SELECT COUNT(*) FROM production_events e
     LEFT JOIN production_batch_items i ON i.id = e.production_batch_item_id
     WHERE i.id IS NULL;   -- must be 0
     ```
9. After a day on live, sanity-check that the log is keeping up:
   ```sql
   SELECT COUNT(*) AS events_today FROM production_events
   WHERE DATE(occurred_at) = CURDATE() AND event_type = 'produced';
   ```
   Compare against the labels the floor says they printed today. They should match.

## Rollback

Low risk, because nothing reads the table.

- **Code:** revert the service and controller changes. The counters keep working exactly as before — they were never removed.
- **Schema:** `php artisan migrate:rollback` drops `production_events`. Because of `cascadeOnDelete` the table owns no data anyone else references, so dropping it cannot corrupt `production_batch_items`.
- If you roll back code but leave the table, the system is still correct — the table just stops growing, and any later backfill (step 03) can be re-run to close the gap.
- If you roll back **after** step 02 has shipped to clients, old clients keep sending `idempotency_key` and the server ignores it. Harmless.

## Depends on / blocks

- **Depends on:** nothing.
- **Blocks: everything else in phase 2.** 02, 03, 04, 05 and 06 all require this table to exist. Ship it first and let it run for at least a few days so the log has real data before anything reads it.
- 07 and 08 (stock balance) are independent of this file and can be worked in parallel by another person.
