# 03 — Backfill opening events

One synthetic opening event per existing `production_batch_item`, so the ledger reconciles from day one. The history is an approximation and must be labelled as one.

**Severity:** Medium / **Effort:** 1 day / **Safe on live:** Yes — writes only to `production_events`, chunked, re-runnable

## Why this matters

Step 01 starts logging events from the moment it deploys. Everything that happened before that is a counter with no rows behind it.

Concrete: an item has `produced_quantity = 500` and `defect_quantity = 12` from work done in January. Step 01 ships in July. `SUM(production_events.quantity)` for that item is `0`. So:

- Step 06's reconcile reports drift of 500 on every pre-existing item — thousands of false alarms, which means the signal gets ignored, which means the command is worthless.
- Step 04's analytics, once switched, reports **zero production before July**. The factory's entire history vanishes from the report.

The backfill closes the gap by writing one opening event per item carrying the pre-existing total. After it runs, `SUM(events) == produced_quantity` for every item, and the ledger is internally consistent from its first day.

## Read this before you run it: the history is not recoverable

Per-event history for the past **never existed**. It was not deleted, not corrupted, not lost — the system never wrote it. No backfill can recover what was never recorded. Anyone who tells the owner "we restored the history" is wrong.

What the backfill produces is a **single lump event per item**, dated with the best available proxy. That is honest bookkeeping — the totals are real, the timestamps are inferred.

**`occurred_at` proxy, in priority order** (all verified to exist in `production_batches`):

1. `production_batches.completed_datetime` — best available. If the batch is finished, its output landed at or before this moment. Closest to true.
2. `production_batches.started_datetime` — fallback for in-progress batches. Places output at the start of the run rather than spread across it. Wrong, but wrong in a bounded, explainable way.
3. `production_batch_items.created_at` — last resort. `started_datetime` is nullable and `planned` batches have never been started.

All three are approximations, and #2 and #3 are quite bad ones. An item whose 500 carpets were woven over three weeks gets all 500 stamped on one instant. That is the reality of the situation — the alternative is having no history at all, which is worse.

**Every backfill event must carry `reason = 'backfill'`.** This is not decoration. It is the only way anyone can later distinguish inferred history from measured history:

```sql
-- "How much of January is real data?"
SELECT reason = 'backfill' AS inferred, SUM(quantity)
FROM production_events
WHERE occurred_at BETWEEN '2026-01-01' AND '2026-01-31'
GROUP BY inferred;
```

When you show the owner the new analytics in step 04, show him this split. He is entitled to know which of his numbers are measured and which are reconstructed. Say it plainly: *"everything before <deploy date> is a single estimated entry per production item, placed on the batch's completion date. The totals are right. The daily distribution before that date is not real."*

## Files to change

| File | Status | Notes |
|---|---|---|
| `tgc_backend/app/Console/Commands/BackfillProductionEvents.php` | new | **`app/Console/Commands/` holds no commands** — it is empty and untracked (git does not track empty directories), so it may not exist on a fresh clone; create it if absent |
| `tgc_backend/app/Models/ProductionEvent.php` | from step 01 | used, not changed |

This is Laravel `^13.0`, so there is no `app/Console/Kernel.php`. Commands in `app/Console/Commands/` are auto-registered. Nothing needs to be added to `bootstrap/app.php`.

## The change

A one-shot artisan command. Not a migration — a migration that writes hundreds of thousands of rows on live is a bad idea (it holds the migration lock, it is all-or-nothing, and `migrate:rollback` would try to undo it).

```php
class BackfillProductionEvents extends Command
{
    protected $signature = 'production:backfill-events
                            {--chunk=500 : rows per batch}
                            {--dry-run  : report only, write nothing}';

    protected $description = 'Write one synthetic opening event per production_batch_item (idempotent).';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $chunk  = (int) $this->option('chunk');
        $now    = now();
        $written = 0;
        $skipped = 0;

        ProductionBatchItem::query()
            ->select('production_batch_items.*')
            ->addSelect([
                'batch_completed' => ProductionBatch::select('completed_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_started'   => ProductionBatch::select('started_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_created_by' => ProductionBatch::select('created_by')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
            ])
            // Only items with something to record.
            ->where(function ($q) {
                $q->where('produced_quantity', '>', 0)
                  ->orWhere('defect_quantity', '>', 0);
            })
            // Idempotency: skip items that already have a backfill event.
            ->whereNotExists(function ($q) {
                $q->select(DB::raw(1))
                  ->from('production_events')
                  ->whereColumn('production_events.production_batch_item_id', 'production_batch_items.id')
                  ->where('production_events.reason', 'backfill');
            })
            ->orderBy('production_batch_items.id')
            ->chunkById($chunk, function ($items) use (&$written, &$skipped, $dryRun, $now): void {
                $rows = [];

                foreach ($items as $item) {
                    $occurredAt = $item->batch_completed
                        ?? $item->batch_started
                        ?? $item->created_at;

                    if ($occurredAt === null) {
                        $this->warn("item {$item->id}: no usable timestamp, skipped");
                        $skipped++;
                        continue;
                    }

                    if ($item->produced_quantity > 0) {
                        $rows[] = [
                            'production_batch_item_id' => $item->id,
                            'event_type'      => ProductionEvent::TYPE_PRODUCED,
                            'quantity'        => (int) $item->produced_quantity,
                            'occurred_at'     => $occurredAt,
                            'user_id'         => $item->batch_created_by,
                            'idempotency_key' => null,
                            'reason'          => 'backfill',
                            'created_at'      => $now,
                        ];
                    }

                    if ($item->defect_quantity > 0) {
                        $rows[] = [
                            'production_batch_item_id' => $item->id,
                            'event_type'      => ProductionEvent::TYPE_DEFECT,
                            'quantity'        => (int) $item->defect_quantity,
                            'occurred_at'     => $occurredAt,
                            'user_id'         => $item->batch_created_by,
                            'idempotency_key' => null,
                            'reason'          => 'backfill',
                            'created_at'      => $now,
                        ];
                    }
                }

                if (! $dryRun && $rows !== []) {
                    DB::table('production_events')->insert($rows);
                }

                $written += count($rows);
                $this->info("… {$written} events prepared");
            }, 'production_batch_items.id');

        $this->info(($dryRun ? '[dry-run] would write ' : 'wrote ') . "{$written} events, skipped {$skipped}");

        return self::SUCCESS;
    }
}
```

Points that matter:

- **Idempotent via `whereNotExists ... reason = 'backfill'`.** Run it twice, it does nothing the second time. That is not optional — this will be interrupted (SSH drops, deploy window closes) and you must be able to just run it again. Do not use `firstOrCreate` per item; it is one query per row and will take hours.
- **Two rows per item, not one.** `produced` and `defect` feed different caches (see the mapping table in step 01), so an item with both needs both. This is why the count of written events exceeds the count of items.
- **`chunkById`, not `chunk`.** `chunk` with an `offset` skips rows when the result set shifts underneath it. `chunkById` keys off the primary key and is stable. Note the explicit column name `'production_batch_items.id'` — needed because of the joined subselects.
- **`user_id` is `production_batches.created_by`** — verified NOT NULL with an FK to `users`, so it always resolves. It is attribution-by-proxy: the batch's creator almost certainly did not print every label. `reason = 'backfill'` is what stops anyone reading it as fact.
- **`->where(produced > 0 OR defect > 0)`** skips planned items with nothing to record. They reconcile at `0 == 0` anyway.
- **Bulk `insert()`, not `ProductionEvent::create()` per row** — ~1000x fewer round-trips.
- Wrap nothing in a transaction. Each chunk is independent; a failure mid-run leaves earlier chunks committed, and re-running resumes cleanly. That is the point of making it idempotent.

## How to verify

1. **Dry run first, always:**
   ```bash
   php artisan production:backfill-events --dry-run
   ```
   Compare its count against expectation:
   ```sql
   SELECT SUM(produced_quantity > 0) + SUM(defect_quantity > 0) AS expected_events
   FROM production_batch_items
   WHERE produced_quantity > 0 OR defect_quantity > 0;
   ```
2. **Snapshot before running** (so you can prove nothing else changed):
   ```sql
   SELECT SUM(produced_quantity), SUM(defect_quantity), COUNT(*) FROM production_batch_items;
   ```
3. Run for real: `php artisan production:backfill-events`
4. **The counters must be untouched** — re-run the snapshot query. Identical numbers. This command writes only to `production_events`; if `production_batch_items` moved, something is very wrong, stop and roll back.
5. **The ledger must reconcile.** This is the whole deliverable:
   ```sql
   SELECT i.id, i.produced_quantity,
          COALESCE(SUM(CASE WHEN e.event_type IN ('produced','scrap','correction')
                            THEN e.quantity END), 0) AS produced_events,
          i.defect_quantity,
          COALESCE(SUM(CASE WHEN e.event_type = 'defect' THEN e.quantity END), 0) AS defect_events
   FROM production_batch_items i
   LEFT JOIN production_events e ON e.production_batch_item_id = i.id
   GROUP BY i.id
   HAVING produced_events <> i.produced_quantity
      OR  defect_events   <> i.defect_quantity;
   ```
   **Must return zero rows.** If it does not, do not proceed to step 04 — you would be repointing the owner's reports at a ledger you already know is wrong.
6. **Idempotency:** run the command a second time. It must report `wrote 0 events`. Re-run the query in #5 — still zero rows.
7. **Check the proxy distribution** — know what you actually produced:
   ```sql
   SELECT DATE(occurred_at) AS d, COUNT(*) AS events, SUM(quantity) AS qty
   FROM production_events WHERE reason = 'backfill'
   GROUP BY d ORDER BY d;
   ```
   Expect visible spikes on batch completion dates. That is the approximation showing through. If you see everything on one or two dates, most batches are falling through to `created_at` — worth understanding before step 04 shows it to the owner.
8. **Timing:** run it on a staging copy of production data first and time it. `SELECT COUNT(*) FROM production_batch_items;` tells you the order of magnitude. Do not discover on live that it takes 40 minutes.

## Rollback

Clean, because backfill rows are self-identifying:

```sql
-- verify the blast radius first
SELECT COUNT(*) FROM production_events WHERE reason = 'backfill';

-- then delete, chunked, to avoid a long lock on live
DELETE FROM production_events WHERE reason = 'backfill' LIMIT 5000;   -- repeat until 0 rows affected
```

Nothing else references these rows and nothing reads `production_events` yet (step 04 has not shipped). Deleting them returns the system to its post-step-01 state exactly. Then fix and re-run.

If step 04 **has** shipped, deleting the backfill will silently zero out all historical production in the owner's reports. Roll back 04 first.

## Depends on / blocks

- **Depends on: 01** — the table and model must exist, and ideally step 01 should have been live long enough that you are confident the dual-write is correct. Backfilling onto a broken dual-write just bakes in the error.
- **Blocks: 04** (analytics would report zero history without it) and **06** (reconcile would report drift on every pre-existing item, making the alert useless).
- Run this **immediately after** step 01 deploys. The window between "01 is live" and "03 has run" is a period where reconcile is noisy — keep it short. There is no gap-correctness problem in either order, though: any item touched by a real event since 01 shipped still gets its opening event here, because the counter already includes those events. Wait — that is the one ordering trap. See below.

**Ordering trap, read carefully:** the opening event uses the item's **current** `produced_quantity`. If step 01 has been live for a week, that counter already includes the week's real events. Backfilling the full current total would double-count that week. The `whereNotExists` guard does not catch this — it only checks for a prior *backfill* row.

Two safe options:

- **(Recommended) Run the backfill in the same maintenance window as step 01's deploy**, before any label is printed. Then the counter contains only pre-event history and the lump is exactly right.
- **If 01 has already been live for a while**, subtract what the log already knows:
  ```php
  $alreadyLogged = (int) DB::table('production_events')
      ->where('production_batch_item_id', $item->id)
      ->whereIn('event_type', ['produced', 'scrap', 'correction'])
      ->sum('quantity');

  $openingQty = (int) $item->produced_quantity - $alreadyLogged;
  // skip the row entirely if $openingQty <= 0
  ```
  and the same for `defect`. Verification step #5 catches the mistake either way — but catch it in staging, not on live.
