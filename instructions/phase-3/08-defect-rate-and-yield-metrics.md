# 08 — Defect rate and yield metrics

Defect data is captured carefully and never reported on. Turn it into defect rate and first-pass yield.

**Severity: Medium / Effort: 1 week / Safe on live: Yes — read-only analytics; adds queries and endpoints, mutates nothing**

## Why this matters

The factory records defects in detail. `defect_documents` (migration `2026_04_12_000001_create_defect_documents_table.php`) holds:

```php
$table->foreignId('production_batch_id')...
$table->foreignId('user_id')...
$table->timestamp('datetime')->useCurrent();     // line 18
$table->text('description');
```

with `defect_document_items` carrying `production_batch_item_id` and `quantity`, plus `defect_document_photos` for evidence. `DefectDocumentController` line 57 rolls each document into the batch line:

```php
->increment('defect_quantity', $itemData['quantity']);
```

So there is a per-batch, per-item, per-operator, photographed, timestamped defect record, and a `defect_quantity` counter on every batch line (`2026_04_11_000003_create_production_batch_items_table.php` line 19).

**None of it is ever reported on.** Verified:

- `grep -rniwE "defect_rate|efficiency|yield|oee|first_pass" app/` returns **nothing**.
- `grep -rniE "defect" app/Services/ProductionAnalyticsService.php app/Services/ProductAnalyticsService.php` returns **nothing**. Neither analytics service references defects in any form.
- `defect_documents.datetime` is read by no analytics code at all. The column exists, is populated on every document, and is never queried.

The only consumer of `defect_quantity` is `ProductionBatchService::incrementProducedQuantity()` line 173, which uses it in the batch-completion condition (`produced_quantity < planned_quantity - defect_quantity`), and `DefectDocumentController` line 124. It drives a state transition and nothing else.

So the factory does the work of recording defects — someone photographs a flawed carpet and writes a description — and gets back a completion threshold. The questions that data was collected to answer are all unanswered:

- Which loom produces the most defects? (`production_batches.machine_id` is right there.)
- Is quality getting better or worse? (`defect_documents.datetime` is right there.)
- Which product/colour/size defects most? (the variant joins already exist in `ProductionAnalyticsService::baseQuery()`.)
- Which operator? (`production_batches.responsible_employee_id`, `defect_documents.user_id`.)

Every join needed already exists in `ProductionAnalyticsService`. This is a week of work because the data model is already right — the reports were simply never written.

Example of what becomes visible: loom 3 runs a 9% defect rate against a 2% factory average. At 500 carpets a week and, say, 40 USD of materials per carpet, that gap is roughly 1,400 USD a week of wool being turned into scrap by one machine that nobody has flagged because nobody can see it.

## The `updated_at` problem — read this before writing any time series

`ProductionAnalyticsService::baseQuery()` line 58:

```php
->whereBetween(DB::raw('DATE(production_batch_items.updated_at)'), [$from, $to])
```

Production analytics buckets by **`updated_at`**. That column moves on *any* write to the row — a label print, a warehouse receipt crediting `warehouse_received_quantity`, a defect increment, an unrelated edit. So a carpet made in March, received in April, and touched by a defect document in May reports as **May production**.

The existing production trend is therefore already unreliable, and any defect time series built on the same basis inherits it. Worse, defects would be systematically mis-bucketed: recording a defect *is itself a write* that moves `updated_at` to the recording date, so a defect always lands in the bucket where it was *noticed*, never where it was *made*. A defect rate computed this way is close to meaningless — it measures inspection activity.

**This is the hard dependency on Phase 2.** Phase 2's `production_events.occurred_at` is a real event time that does not move. Until it exists:

- `defect_documents.datetime` (line 18, `useCurrent`) is the honest defect timestamp — it is set once and never touched. **Use it, not `updated_at`.** It is the whole reason the column exists and it has never been read.
- Production output has no equivalent honest timestamp. `production_batches.started_datetime` is the nearest, but see `03-fix-batch-state-machine.md`: it is force-set to `now()` at creation (`ProductionBatchService::create()` line 41), so it records data-entry time, not production time.

Therefore: **defect counts can be bucketed correctly today; production counts cannot.** A defect *rate* is a ratio of the two, so the denominator is unreliable until Phase 2 or until `started_datetime` becomes real. Ship the rate anyway — it is directionally useful and vastly better than nothing — but do not present a daily trend as precise, and do not let anyone build a target or a bonus scheme on it before `occurred_at` is real. Write that caveat into the endpoint's documentation, not just into this file.

## Files to change

- `tgc_backend/app/Services/ProductionAnalyticsService.php` — `getReport()` line 20, `baseQuery()` line 48, `querySummary()` line 62, `queryTrend()` line 79
- `tgc_backend/app/Http/Resources/ProductionAnalyticsResource.php`
- `tgc_backend/app/Http/Requests/Analytics/ProductionAnalyticsRequest.php`
- `tgc_backend/app/Http/Controllers/Api/V1/ProductionAnalyticsController.php`
- possibly a new `DefectAnalyticsService` if the production service gets unwieldy — it already has twelve methods
- client: production analytics screens

## The change

### 1. Defect rate

```
defect_rate = defects / (produced + defects)
```

Define the denominator deliberately and write it in a comment, because both conventions exist and the difference is silently large:

- `defects / produced` — defects per good unit. At high defect rates this exceeds 100%, which confuses people.
- `defects / (produced + defects)` — defects as a share of everything made. Bounded 0–100%. **Use this one.**

`produced_quantity` and `defect_quantity` are separate counters on `production_batch_items` — a defective carpet increments `defect_quantity`, and whether it also incremented `produced_quantity` depends on whether it was labelled first. That ambiguity is real and is why `02-production-units-serials.md` matters here: with unit rows, `good` / `defect` / `scrapped` are explicit states and the denominator stops being a judgement call.

Add to `querySummary()` (line 62), reusing the existing `baseQuery()` joins:

```php
'COALESCE(SUM(production_batch_items.defect_quantity), 0) as total_defects',
```

then in the returned array:

```php
$produced = (int) ($row->total_produced ?? 0);
$defects  = (int) ($row->total_defects ?? 0);
$base     = $produced + $defects;

'total_defects' => $defects,
'defect_rate'   => $base > 0 ? round($defects / $base * 100, 2) : null,
```

**`null`, not `0`, when the denominator is zero.** A machine that made nothing has no defect rate; reporting 0% would rank it as the best loom in the factory. This is the single most likely bug in this file.

Note `baseQuery()` line 57 filters `produced_quantity > 0`. A batch line that produced nothing but recorded defects is **excluded entirely** — the worst possible case is invisible. For defect reporting, drop that filter or the numbers understate reality. This is a real behaviour change to a shared method: either parameterise `baseQuery()` or give defects their own base query. Do not silently change the existing production report's filter.

### 2. Break it down

The existing service already has `queryByType()` (line 106), `queryByColor()` (127), `queryBySize()` (148), `queryByQuality()` (174), `queryByEdge()` (195). Add `defect_quantity` and `defect_rate` to each — the joins are already there, so each is a one-line `selectRaw` addition plus the rate calculation.

Then add the two breakdowns that do not exist and are the most actionable:

- **by machine** — `production_batches.machine_id` is on the already-joined `production_batches`. This is the loom comparison, and it is the reason to do this work.
- **by operator** — `production_batches.responsible_employee_id`.

Both are single joins onto existing tables. Be careful with the operator one: a defect rate per named person is a management instrument, not just a chart. Confirm the factory wants it before shipping it, and note that `responsible_employee_id` is set to the *creator* at `ProductionBatchService::create()` line 42, so today it identifies whoever typed the batch in, not necessarily who ran the loom. Until `03-fix-batch-state-machine.md` Path A makes `start()` reachable and sets the responsible employee at start time, an operator defect rate attributes defects to the wrong person. **Do not ship the by-operator breakdown before 03.** Ship by-machine now.

### 3. First-pass yield

```
first_pass_yield = units good on the first attempt / total units started
```

The strict definition requires knowing about rework — a carpet fixed and passed is *not* first-pass. There is no rework concept in this system: a defect document records a quantity and increments a counter, with no notion of a carpet being repaired and re-inspected.

So today FPY collapses to `produced / (produced + defects)`, which is exactly `1 − defect_rate`. Shipping both is shipping the same number twice under two names, which is worse than shipping one — people will assume they differ and read meaning into the gap.

**Recommendation: ship `defect_rate` now, and do not ship `first_pass_yield` until it can differ from it.** It can differ once `02-production-units-serials.md` lands, because a unit's status history distinguishes:

- `good` from the start → first-pass
- `defect` → later `good` (repaired) → passed, but not first-pass
- `scrapped` → never passed

That is real FPY and it needs the unit-level status transitions. Then:

```sql
SELECT
    SUM(status IN ('good','received','shipped') AND reprint_count = 0) / COUNT(*) AS fpy
FROM production_units
WHERE production_batch_item_id = ?;
```

(Refine once the status history exists — the current-status column alone cannot tell you a unit was ever `defect`. That argues for a `production_unit_events` table or for Phase 2's `production_events` carrying unit status transitions, which is the natural division of labour described in file 02.)

If FPY is wanted before then, say plainly in the API and the UI that it is `1 − defect_rate` and does not account for rework. Do not let it look like an independent measurement.

### 4. OEE — correction to the brief: not currently possible

The brief said "if machine data allows — check the machines table". Checked. The full `machines` table (`database/migrations/2026_04_11_000001_create_machines_table.php`):

```php
Schema::create('machines', function (Blueprint $table): void {
    $table->id();
    $table->string('name');
    $table->string('model_name')->nullable();
    $table->timestamps();
});
```

`id`, `name`, `model_name`, timestamps. That is all.

OEE is `Availability × Performance × Quality`:

| Factor | Needs | Have? |
|---|---|---|
| Quality | good / total | **Yes** — this is defect rate |
| Performance | actual rate ÷ ideal cycle time | **No** — no ideal cycle time on `machines`, and no reliable per-carpet timestamps |
| Availability | run time ÷ planned production time | **No** — no shift calendar, no downtime records, no run/stop events |

Two of three factors have no data behind them. **Do not build OEE.** An OEE number computed with assumed availability and assumed cycle time is a fabricated number that looks authoritative, gets reported upward, and gets acted on. It is worse than no number.

What OEE would require, as a separate project — do not start it inside this week:

1. `machines.ideal_cycle_time_seconds` (per product type, realistically, since a 2×3 m carpet is not a 1×1 m carpet — so a `machine_product_rates` table, not a column).
2. A shift calendar defining planned production time per machine per day.
3. Machine run/stop events — realistically from the loom's own PLC/controller, not from humans typing.

Item 3 is the expensive one and the one that makes the other two worth having. Until the looms are instrumented, OEE is not available at any price in software. Say this to whoever asked for OEE, and offer **Quality** — the one factor that is fully available today and is what this file delivers.

### 5. Endpoints

Extend the existing `GET /api/v1/analytics/production` rather than adding a parallel endpoint. It already takes `from`, `to`, `trend_by` (`ProductionAnalyticsRequest`), and the client already consumes it. Adding `total_defects`, `defect_rate` and a `by_machine` block to the existing response is additive and cannot break an existing client.

For the defect trend, use `defect_documents.datetime` as the time basis — not `production_batch_items.updated_at`. This means the defect trend and the production trend are bucketed on **different clocks**, and will not be directly comparable. Say so in the response or the UI. It is still the right call: one honest series and one unreliable series beats two unreliable series.

## How to verify

1. A batch with 100 produced, 5 defects → `defect_rate` 4.76% (`5 / 105`), not 5%. Confirm the denominator convention in the code matches the one documented here.
2. A batch with 0 produced, 0 defects → `defect_rate` is `null`, not 0. Check it does not rank first in a by-machine sort.
3. A batch with 0 produced and 3 defects → appears in the report at 100%. This is the `baseQuery()` line 57 filter; if the batch is missing, the filter is still excluding it.
4. By-machine breakdown across a month: the rates sum consistently with the total. Take the output to the factory and ask whether the worst loom is the one they would have named. If it is not, the query is wrong — the floor already knows this answer informally, and that is your test oracle.
5. Defect trend by day uses `defect_documents.datetime`: record a defect against a three-month-old batch. It must appear on **today**, and must **not** move the production figure for today.
6. Then observe the mis-bucketing directly: that same defect document has just moved `production_batch_items.updated_at` to today, so the *production* report now counts that old batch's output as today's. Confirm this happens. It is the existing bug, it is why Phase 2 matters, and seeing it once is worth more than reading about it.
7. Existing `/analytics/production` consumers still work — response is additive only. Run the route smoke test from `01-tests-and-ci.md`.
8. Performance: `defect_quantity` is on `production_batch_items`, already joined, so no new join. If the report slows, it is the removed `produced_quantity > 0` filter widening the scan — check the plan.

## Rollback

Read-only. Revert the service and resource changes; no data is written and no schema changes. The only user-visible loss is the reports themselves. Nothing else depends on them.

If the numbers turn out to be wrong after release, **remove the report rather than leaving it up with a caveat**. A wrong defect rate on a dashboard becomes a target, and people will optimise against it.

## Depends on / blocks

- **Depends on Phase 2 for the time series to be meaningful.** `production_batch_items.updated_at` (line 58) is not an event time. The defect trend can use `defect_documents.datetime` and is honest today; the production denominator cannot be correctly bucketed until `occurred_at` is real. Ship the aggregate rate now, treat the daily trend as indicative, and revisit when Phase 2 lands. This is the main caveat on the whole file and it belongs in the UI, not just here.
- **Depends on `03-fix-batch-state-machine.md`** for the by-operator breakdown — `responsible_employee_id` is the batch's creator today (`create()` line 42), so per-operator defect rates would name the wrong person. Ship by-machine first; by-operator after 03 Path A.
- **Improved by `02-production-units-serials.md`.** Real first-pass yield needs unit-level status history. Without it, FPY is `1 − defect_rate` and should not be shipped as a separate metric.
- **OEE depends on machine instrumentation that does not exist.** Not a software task. Do not schedule it.
- **Depends on `01-tests-and-ci.md`** lightly — the smoke test covers the analytics routes.
- **Blocks nothing.** Read-only and self-contained; can run in parallel with anything. Good candidate for a week when a riskier item is blocked on factory input.
