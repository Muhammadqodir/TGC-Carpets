# 06 — `php artisan production:reconcile`

Assert that the counters equal the log, nightly. This is what turns silent drift into a signal.

**Severity:** High — without it the whole phase is unverified / **Effort:** 2 days / **Safe on live:** Yes read-only; `--fix` writes and needs care

## Why this matters

Phase 2's design is: `produced_quantity` and `defect_quantity` are **caches** of `production_events`, written in the same transaction. A cache that is never checked against its source is just a second number that happens to be nearby.

Every dual-write in this phase can drift:

- a code path that increments the counter but forgets the event (someone adds a feature in six months and copies the pre-phase-2 pattern)
- an event written outside a transaction, or a transaction that partially fails
- a raw `UPDATE production_batch_items SET produced_quantity = ...` run by hand at 2am to fix "just this one item"
- `ProductionBatchService::updateItem()` (line 201) — **which drifts today, by design**: it lets a client `PATCH` `produced_quantity` and `defect_quantity` directly, writing the counter with **no event at all**. Every call to it is guaranteed drift. See below.

Without this command, drift is silent and permanent. Step 04's analytics reads the log; the labeling screen, warehouse FIFO credit and batch auto-completion all read the counter. When they disagree, the report says 500 and the floor screen says 497, nobody knows which is right, and confidence in the entire system evaporates — including the parts that are correct.

Concrete: a bad deploy drops the event write from the label path but keeps the increment. For three weeks the counter climbs and the log does not. Analytics under-reports by thousands. It surfaces when the owner asks why October was catastrophic, and by then nobody can reconstruct what happened. With this command you get an alert the first night.

**This is the step that makes the cache-plus-log design trustworthy rather than merely plausible.** Do not skip it, and do not let it be the thing that slips when the three weeks get tight.

## Files to change

| File | Status | Notes |
|---|---|---|
| `tgc_backend/app/Console/Commands/ProductionReconcile.php` | new | the command |
| `tgc_backend/routes/console.php` | 1–9 | currently only the stock `inspire` command; add the schedule here |

Laravel `^13.0` — no `app/Console/Kernel.php`. Commands auto-register from `app/Console/Commands/`; scheduling goes in `routes/console.php` via the `Schedule` facade.

## The change

### 1. The query

One `GROUP BY` per item, using step 01's event-type mapping (`produced`/`scrap`/`correction` → `produced_quantity`; `defect` → `defect_quantity`):

```sql
SELECT
    i.id,
    i.production_batch_id,
    i.produced_quantity,
    COALESCE(SUM(CASE WHEN e.event_type IN ('produced','scrap','correction')
                      THEN e.quantity END), 0)                    AS produced_log,
    i.produced_quantity
      - COALESCE(SUM(CASE WHEN e.event_type IN ('produced','scrap','correction')
                          THEN e.quantity END), 0)                AS produced_drift,
    i.defect_quantity,
    COALESCE(SUM(CASE WHEN e.event_type = 'defect' THEN e.quantity END), 0) AS defect_log,
    i.defect_quantity
      - COALESCE(SUM(CASE WHEN e.event_type = 'defect' THEN e.quantity END), 0) AS defect_drift
FROM production_batch_items i
LEFT JOIN production_events e ON e.production_batch_item_id = i.id
GROUP BY i.id, i.production_batch_id, i.produced_quantity, i.defect_quantity
HAVING produced_drift <> 0 OR defect_drift <> 0
ORDER BY ABS(produced_drift) + ABS(defect_drift) DESC;
```

`LEFT JOIN` matters — an item with zero events and a non-zero counter is the single most important case to catch, and an `INNER JOIN` would hide it.

Drift is signed and the sign is diagnostic:

- **positive** (`counter > log`) — a counter moved without an event. `updateItem()`, or a manual `UPDATE`, or a missing dual-write.
- **negative** (`counter < log`) — an event without a counter move. Rarer; usually a partially-applied transaction or a botched backfill.

### 2. The command

```php
class ProductionReconcile extends Command
{
    protected $signature = 'production:reconcile
                            {--fix       : write correction events to close the drift}
                            {--item=     : check a single production_batch_item id}
                            {--limit=50  : max rows to print}';

    protected $description = 'Assert production_batch_items counters == SUM(production_events).';

    public function handle(): int
    {
        $drifted = $this->findDrift($this->option('item'));

        if ($drifted->isEmpty()) {
            $this->info('production:reconcile — OK, ' . $this->itemCount() . ' items, no drift.');
            return self::SUCCESS;
        }

        $this->error("production:reconcile — DRIFT on {$drifted->count()} item(s).");

        $this->table(
            ['item', 'batch', 'produced (cache/log/drift)', 'defect (cache/log/drift)'],
            $drifted->take((int) $this->option('limit'))->map(fn ($r) => [
                $r->id,
                $r->production_batch_id,
                "{$r->produced_quantity} / {$r->produced_log} / {$r->produced_drift}",
                "{$r->defect_quantity} / {$r->defect_log} / {$r->defect_drift}",
            ]),
        );

        $this->warn('Totals — produced drift: ' . $drifted->sum('produced_drift')
                  . ', defect drift: ' . $drifted->sum('defect_drift'));

        if ($this->option('fix')) {
            $this->applyFix($drifted);
        }

        // Non-zero exit = the scheduler / monitoring treats this as a failure.
        return self::FAILURE;
    }
}
```

**Report, in this order:**

1. **count of drifted items** — 1 is a bug, 5000 is a bad deploy; the response differs
2. **net drift, produced and defect** — the size of the lie in carpets
3. **worst offenders** — capped by `--limit`; do not print 5000 rows into a cron email
4. **exit code** — `FAILURE` on any drift. This is the whole alerting mechanism.

### 3. `--fix`

`--fix` **does not `UPDATE` the counter.** It appends a `correction` event that closes the gap, and lets the counter stand:

```php
private function applyFix($drifted): void
{
    $userId = (int) config('reconcile.system_user_id');   // a real users row — FK is NOT NULL

    foreach ($drifted as $row) {
        DB::transaction(function () use ($row, $userId): void {
            if ($row->produced_drift != 0) {
                ProductionEvent::create([
                    'production_batch_item_id' => $row->id,
                    'event_type' => ProductionEvent::TYPE_CORRECTION,
                    'quantity'   => $row->produced_drift,   // signed: closes log → cache
                    'occurred_at'=> now(),
                    'user_id'    => $userId,
                    'reason'     => 'reconcile: closing produced drift of ' . $row->produced_drift,
                    'created_at' => now(),
                ]);
            }

            if ($row->defect_drift != 0) {
                ProductionEvent::create([
                    'production_batch_item_id' => $row->id,
                    'event_type' => ProductionEvent::TYPE_DEFECT,
                    'quantity'   => $row->defect_drift,
                    'occurred_at'=> now(),
                    'user_id'    => $userId,
                    'reason'     => 'reconcile: closing defect drift of ' . $row->defect_drift,
                    'created_at' => now(),
                ]);
            }
        });
    }
}
```

Be clear about what `--fix` is choosing:

- **It trusts the cache over the log.** That is the right default *only* because the cache is what the floor sees and acts on. It is a bookkeeping entry to make the two agree, not a claim about what physically happened.
- **`occurred_at = now()`.** The correction happens today. Backdating it to guess when the drift started would rewrite closed periods in step 04's report and break the immutability `resolveTtl` relies on.
- **It is never automatic.** `--fix` must **not** be in the schedule. Drift means something is broken; papering over it nightly means you never find out. A human runs `--fix` after understanding the cause. Say this in the runbook.
- **A `defect` drift fix uses `defect`, not `correction`** — per step 01's mapping, `correction` feeds `produced_quantity` only.

### 4. Schedule it

`routes/console.php`:

```php
use Illuminate\Support\Facades\Schedule;

Schedule::command('production:reconcile')
    ->dailyAt('02:30')
    ->onFailure(function (): void {
        // Alert. Do NOT let this be a log line nobody reads.
    });
```

02:30 is after the factory stops and before anyone looks at a report.

**Alerting is the entire point of this file.** A non-zero exit code that goes nowhere is not a signal. Wire `onFailure` to whatever the team actually reads — Telegram bot, email, anything with a human on the other end. Confirm the scheduler is even running (`* * * * * cd /path && php artisan schedule:run >> /dev/null 2>&1` in the deploy user's crontab); on a box with no cron entry this command is decoration. Verify that before you call this step done.

### 5. `updateItem()` will trip this on day one

`ProductionBatchService::updateItem()` (line 199, write at line 201) does:

```php
$item->update(array_filter([
    'produced_quantity' => $data['produced_quantity'] ?? null,
    'defect_quantity'   => $data['defect_quantity'] ?? null,
    'notes'             => ...,
], fn ($v) => $v !== null));
```

It sets counters absolutely, with no event, from `PATCH /production-batches/{batch}/items/{item}` (route line 177). Every call is guaranteed drift, and the reconcile alert will fire the first time anyone uses the screen behind it.

Do not discover this at 02:30. Decide before scheduling:

- **(Recommended) Convert it to a `correction` event** in the same transaction: read the current counter, compute the delta, write `('correction', delta)`, then update. It becomes an auditable manual adjustment — exactly what the event type is for, and it gains the "who changed this and why" that the owner asked for.
- Or reject quantity changes on this endpoint and route operators through the label/defect flows.
- Or, minimally, exclude nothing and accept the noise — **do not do this**; a reconcile that always reports drift is one people learn to ignore, and you have built an alarm that trains its audience to disable it.

Whichever you pick, do it **before** the first scheduled run. Baseline the command against a clean staging dataset so the first live drift report is a real signal.

## How to verify

No test suite. Manual.

1. **Clean baseline.** After step 03's backfill, run:
   ```bash
   php artisan production:reconcile
   ```
   Must print OK and exit 0. Confirm the exit code — `echo $?` → `0`. If it reports drift here, the backfill or the dual-write is wrong; fix that first, this command is just the messenger.
2. **Inject drift, confirm detection.** On staging:
   ```sql
   UPDATE production_batch_items SET produced_quantity = produced_quantity + 7 WHERE id = <ITEM>;
   ```
   ```bash
   php artisan production:reconcile --item=<ITEM>; echo "exit=$?"
   ```
   Must report `produced_drift = 7` and `exit=1`. **A reconcile command that has never caught a planted bug is not known to work** — this check is not optional.
3. **Negative drift.** Insert an event directly with no counter move:
   ```sql
   INSERT INTO production_events
     (production_batch_item_id, event_type, quantity, occurred_at, user_id, created_at)
   VALUES (<ITEM>, 'produced', 3, NOW(), 1, NOW());
   ```
   Must report `produced_drift = -3`.
4. **Zero-event item.** An item with `produced_quantity > 0` and no events must appear (this is the `LEFT JOIN` check):
   ```sql
   DELETE FROM production_events WHERE production_batch_item_id = <ITEM>;
   ```
   Drift must equal the full counter. If it reports OK, you used an `INNER JOIN`.
5. **`--fix` closes it, without touching the counter.** With drift of +7 present:
   ```bash
   php artisan production:reconcile --item=<ITEM> --fix
   php artisan production:reconcile --item=<ITEM>; echo "exit=$?"
   ```
   Second run: OK, exit 0. Then confirm the counter was **not** rewritten and a correction row exists:
   ```sql
   SELECT produced_quantity FROM production_batch_items WHERE id = <ITEM>;   -- unchanged
   SELECT event_type, quantity, reason FROM production_events
   WHERE production_batch_item_id = <ITEM> ORDER BY id DESC LIMIT 2;         -- ('correction', 7)
   ```
6. **`updateItem` behaviour.** `PATCH /api/v1/production-batches/<BATCH>/items/<ITEM>` with `{"produced_quantity": 99}`, then reconcile. Whatever you decided in §5, confirm you get the intended result — a `correction` event and no drift, or a 422. Not silent drift.
7. **Performance.** This scans `production_events` in full. Time it against production-sized data:
   ```sql
   SELECT COUNT(*) FROM production_events;
   ```
   If it runs long, the `GROUP BY` is using `idx_item_time`'s leading column — confirm with `EXPLAIN`. At factory scale a full scan at 02:30 is fine; do not optimise before measuring.
8. **The alert actually fires.** Leave planted drift in place on staging, wait for (or force) the scheduled run: `php artisan schedule:test --name="production:reconcile"`. **Confirm a human receives something.** If the notification does not arrive, this step is not done, regardless of how well the command works.

## Rollback

The safest step in the phase.

- **Read-only by default.** Removing the `Schedule::command(...)` line from `routes/console.php` stops it entirely. Deleting the command file removes it. Neither touches data.
- **`--fix` writes `correction` and `defect` events.** They are identifiable and reversible:
  ```sql
  SELECT * FROM production_events WHERE reason LIKE 'reconcile:%';
  ```
  Reverse with compensating events (append-only — do not `DELETE`), or if a `--fix` run was flatly wrong and nothing has read the log since, delete those rows by `reason` and re-run.
- If reconcile is noisy and you cannot fix the cause immediately, **narrow it rather than disabling it** — schedule with `--item` scoping or filter known-bad items and keep the alert alive for everything else. A disabled alarm is how you end up back where this phase started.

## Depends on / blocks

- **Depends on: 01** (the log), **03** (without the backfill every pre-existing item reports drift and the alert is worthless on day one).
- **Depends in practice on: 05** — while `DefectDocumentController::destroy()` still leaks (never decrements `defect_quantity`), defect drift is permanent and expected, which is exactly the noise that makes an alert useless. Either ship 05 first or scope reconcile to `produced_quantity` until it lands.
- **Should be scheduled before 04 flips its flag.** Once the owner's reports read the log, you want an alert if cache and log disagree — otherwise the first person to notice is him, asking why the report changed.
- **Blocks:** nothing. But without it, steps 01–05 are a design you *believe* works rather than one you can demonstrate works.
- 08 is the same command shape for stock. Build this one first, then copy the structure.
