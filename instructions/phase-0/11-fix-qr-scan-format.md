# Fix the QR scan format — no printed label can be scanned

The backend regex accepts a format the client has never printed. All three client QR formats return 400.

**Severity:** High · **Effort:** 2 h · **Safe on live:** Yes — the endpoint currently rejects 100% of real input, so any change is an improvement

**Finding:** SCAN-1 · **Depends on:** nothing

**Status:** ✅ Implemented 2026-07-15 — see [DEPLOY.md](DEPLOY.md) before shipping.

## Why this matters

`app/Http/Controllers/Api/V1/ProductionBatchController.php:321`:

```php
if (!preg_match('/PB\{(\d+)\}\s+PBI\{(\d+)\}/', $code, $matches)) {
    return response()->json(['message' => 'Invalid QR code format. Expected: PB{batchId} PBI{itemId}'], 400);
}
```

The Flutter client prints **three different formats. None of them match this regex, and they don't match each other:**

| Where | Emits | Example | Matches regex? |
|---|---|---|---|
| `labeling_page.dart:685` — **the real print path** | `'P${item.batchId} I${item.id}'` | `P123 I456` | **No** — no `PB{`, no braces |
| `print_history_page.dart:276` — reprint from history | `'PB{${item.batchId}} VAR{${item.variantId}}'` | `PB{123} VAR{456}` | **No** — `VAR{` ≠ `PBI{` |
| `labeling_page.dart:480` — preview mock | `'P1 I1'` | `P1 I1` | **No** |

So `GET /production-batches-scan?code=P123 I456` → **400 "Invalid QR code format"**. The scan feature has never worked in production.

Note the reprint path is worse than a format mismatch: it encodes **`variantId`**, not `itemId`. Even after a regex fix it would resolve to the wrong entity — variant IDs and batch-item IDs are different sequences, so it would silently return *some other carpet's* data whenever the numbers happen to collide.

### Why you can't just fix the client

**The labels are already glued to carpets.** Every carpet in the warehouse and every carpet already shipped carries `P{batchId} I{itemId}`. You cannot recall them. Whatever the client prints from tomorrow, the backend must be able to read what is physically on the goods today.

## Files to change

- `app/Http/Controllers/Api/V1/ProductionBatchController.php` — `scanItem()`, the regex at line 321
- `tgc_client/lib/features/labeling/presentation/pages/print_history_page.dart:276` — the wrong-entity reprint
- `tgc_client/lib/features/labeling/presentation/pages/labeling_page.dart:480` — the preview mock

## The change

**Widen the backend to accept what is physically printed. Then fix the client to converge on one format.**

### 1. Backend — accept both brace and non-brace forms

```php
// Accept:
//   P{batchId} I{itemId}      — printed by labeling_page.dart (all existing physical labels)
//   PB{batchId} PBI{itemId}   — the documented format, never actually printed
if (! preg_match('/^P(?:B)?\{?(\d+)\}?\s+(?:PB)?I\{?(\d+)\}?$/i', trim($code), $matches)) {
    return response()->json([
        'message' => 'QR kod formati noto\'g\'ri. Kutilgan format: P{batchId} I{itemId}',
    ], 400);
}

$batchId = (int) $matches[1];
$itemId  = (int) $matches[2];
```

Anchor with `^…$` — the current regex is unanchored, so `GARBAGE PB{1} PBI{2} MORE` parses happily.

Do **not** try to also accept `VAR{...}` by treating it as an item id. It is a variant id; accepting it would return confidently wrong data. Leave the reprint path erroring until the client is fixed — a 400 is much better than the wrong carpet.

### 2. Client — one format, one place

`P${item.batchId} I${item.id}` is the format on physical goods, so it wins by default. Put it in a single function used by both the print and reprint paths, rather than two string literals in two files that have already drifted apart once:

```dart
String buildLabelQr({required int batchId, required int itemId}) => 'P$batchId I$itemId';
```

Then fix `print_history_page.dart:276` to pass `item.id` (the batch item), **not** `item.variantId`. Check the model — if `PrintHistoryItem` carries only `variantId`, that's a data-plumbing fix, and it's the real reason this path is wrong.

Update the preview at `labeling_page.dart:480` to call the same function with mock ids, so a mock can never again imply a format the server doesn't accept.

### Longer term

`phase-3/02` replaces this entirely with a per-carpet serial (`TGC-U-00001234`). The current QR identifies the *batch line*, so all 50 carpets in a 50-unit line carry an **identical** code — you cannot tell two carpets apart even when scanning works. Don't build compatibility machinery here; just make the existing labels readable.

## How to verify

```bash
# 1. The format on every physical label today — must return 200
curl -G -H "Authorization: Bearer <token>" \
     --data-urlencode "code=P123 I456" \
     "https://<host>/api/v1/production-batches-scan"

# 2. The documented format — must still return 200
curl -G -H "Authorization: Bearer <token>" \
     --data-urlencode "code=PB{123} PBI{456}" \
     "https://<host>/api/v1/production-batches-scan"

# 3. Junk — must return 400, not a match
curl -G -H "Authorization: Bearer <token>" \
     --data-urlencode "code=hello world" \
     "https://<host>/api/v1/production-batches-scan"

# 4. Unanchored-garbage regression — must return 400
curl -G -H "Authorization: Bearer <token>" \
     --data-urlencode "code=JUNK P123 I456 JUNK" \
     "https://<host>/api/v1/production-batches-scan"
```

Use real ids from:
```sql
SELECT production_batch_id, id FROM production_batch_items LIMIT 5;
```

5. Confirm a mismatched pair still 404s (the existing `where('production_batch_id', $batchId)` guard): `code=P999 I456` where item 456 belongs to a different batch.
6. **Scan an actual printed carpet with the actual app.** This is the only test that proves it — everything above tests your assumption about what's on the label. Find a carpet in the warehouse and scan it.

## Rollback

Revert the backend commit — the regex returns to rejecting everything, which is the current state. The client change is independent and can be reverted separately.

## Worth asking the owner

The scan feature has never worked. Ask how staff currently identify a carpet in the warehouse — the answer tells you what the feature actually needs to do, and whether anyone has been maintaining a paper workaround this whole time. It also puts a value on `phase-3/02`.
