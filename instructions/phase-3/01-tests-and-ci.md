# 01 — Tests and CI

Three targeted test suites and a GitHub Actions workflow, so that a dead endpoint cannot reach the factory floor again.

**Severity: High / Effort: 1 week / Safe on live: Yes — adds files only, touches no runtime code**

## Why this matters

The repository has no tests and no CI. `tests/` contains exactly three files:

- `tgc_backend/tests/TestCase.php`
- `tgc_backend/tests/Unit/ExampleTest.php`
- `tgc_backend/tests/Feature/ExampleTest.php`

Both are the stock Laravel `assertTrue(true)` examples. There is no `.github/workflows` directory anywhere in the repository. (The only `.github` content that exists is `/.github/instructions/tgc-carpet.instructions.md` at the repository root — an editor instruction file, not CI.)

Every Phase 0 "endpoint completely dead" bug would have been caught by a single request assertion:

1. **`DashboardController` HTTP 500 on every call.** `tgc_backend/app/Http/Controllers/Api/V1/DashboardController.php` line 43 references `StockMovement::TYPE_IN`, but the imports (lines 5–9) are only `Controller`, `WarehouseDocument`, `JsonResponse`, `Request`, `DB`. There is no `use App\Models\StockMovement;`. Every call to `GET /api/v1/dashboard/stats` throws `Error: Class "App\Http\Controllers\Api\V1\StockMovement" not found`. One `$this->get('/api/v1/dashboard/stats')->assertOk()` catches it.

2. **Warehouse document editing fails 100%.** `tgc_backend/app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php` (lines 25–30) has no `items.*.product_color_id` rule, while the Store request has it at line 26. Because `validated()` returns only validated keys, `WarehouseDocumentService::syncItems()` line 137 reads `$itemData['product_color_id']` off an array that never contains it. Every update with items dies. One update test catches it.

A third bug of exactly this class is live right now and is documented in `02-production-units-serials.md`: the scan endpoint rejects every QR code the client actually prints. It has presumably been broken for as long as it has existed, because nothing ever calls it in a test.

This is the entire argument for the smoke test. Three dead endpoints, one root cause: nothing ever issued an HTTP request to this application outside production.

**Do not chase coverage.** A coverage target on this codebase would produce hundreds of low-value tests over resources and form requests, take months, and still miss the bugs above. Write tests for three things, in this order, and stop.

## Files to change

New files only:

- `tgc_backend/tests/Feature/Smoke/RouteSmokeTest.php`
- `tgc_backend/tests/Feature/Stock/StockLedgerTest.php`
- `tgc_backend/tests/Feature/Money/MoneyFormulaTest.php`
- `tgc_backend/database/factories/*` (most models have no factory yet — check `tgc_backend/database/factories/` before writing)
- `tgc_backend/.github/workflows/ci.yml` — **note:** put it at the repository root as `/.github/workflows/ci.yml`, not inside `tgc_backend/`, or Actions will not find it. Paths in the workflow then need the `tgc_backend` working directory (shown below).

Modified:

- `tgc_backend/phpunit.xml` — see the database problem below.

## The database problem — solve this first

This is a real blocker, not a nitpick. `tgc_backend/phpunit.xml` sets:

```xml
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

`tgc_backend/config/database.php` line 20 agrees: `'default' => env('DB_CONNECTION', 'sqlite')`, and `.env.example` line 23 says `DB_CONNECTION=sqlite`. But production runs MySQL, and **eight migrations contain raw MySQL-only DDL** that sqlite cannot parse:

```
database/migrations/2026_04_07_000004_migrate_transaction_items_to_variants.php
database/migrations/2026_04_07_000006_reparent_product_variants_to_product_colors.php
database/migrations/2026_04_07_000007_move_sku_to_product_variants.php
database/migrations/2026_04_11_000001_add_planned_status_to_orders_table.php
database/migrations/2026_04_13_000001_add_shipped_status_to_orders_table.php
database/migrations/2026_04_13_000004_convert_type_columns_to_enum.php
database/migrations/2026_04_30_000001_simplify_stock_movements_type.php
database/migrations/2026_05_04_000001_change_users_role_to_json.php
```

For example `2026_04_30_000001_simplify_stock_movements_type.php` lines 33–37:

```php
DB::statement("
    ALTER TABLE stock_movements
    MODIFY COLUMN movement_type
        ENUM('in','out') NOT NULL
");
```

sqlite has no `MODIFY COLUMN` and no `ENUM`. `RefreshDatabase` on sqlite fails at migration time — you never reach a single assertion.

**Resolution: run tests on MySQL, not sqlite.** Do not rewrite the migrations to be portable. The production schema depends on MySQL enum semantics; a test suite running a sqlite-shaped schema would be testing a database you do not operate, which is worse than no test. Change `phpunit.xml`:

```xml
<env name="DB_CONNECTION" value="mysql"/>
<env name="DB_DATABASE" value="tgc_testing"/>
<env name="DB_HOST" value="127.0.0.1"/>
<env name="DB_PORT" value="3306"/>
<env name="DB_USERNAME" value="root"/>
<env name="DB_PASSWORD" value="root"/>
```

Remove the `DB_URL` line. Every developer then needs a local `tgc_testing` schema; CI gets one from a service container. `RefreshDatabase` wraps each test in a transaction, so the suite is still fast — the migration run is the only slow part, and `--parallel` is not worth it at 40 tests.

Verify before writing any test:

```bash
cd tgc_backend
mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS tgc_testing"
php artisan test
```

If migrations do not complete against an empty MySQL schema, fix that before continuing. Everything below depends on it.

## The change

### 1. Stock ledger tests (~15 tests)

The ledger is `stock_movements`. It is written only by `WarehouseDocumentService::syncItems()` (line 133) and reversed by `reverseMovements()` (line 177). Cover every warehouse document type, its reversal, and the round-trip to zero.

`WarehouseDocument::TYPES` (`app/Models/WarehouseDocument.php` lines 20–25) is `in`, `out`, `adjustment`, `return`. For each type: create a document with items, assert the movements written, then delete/reverse the document and assert the net returns to zero.

```php
public function test_in_document_then_reversal_nets_to_zero(): void
{
    $variant = ProductVariant::factory()->create();
    $user    = User::factory()->create();

    $doc = $this->service->create([
        'type'          => WarehouseDocument::TYPE_IN,
        'document_date' => now()->toDateString(),
        'items'         => [[
            'product_id'       => $variant->productColor->product_id,
            'product_color_id' => $variant->product_color_id,
            'product_size_id'  => $variant->product_size_id,
            'quantity'         => 10,
        ]],
    ], $user->id);

    $this->assertSame(10, $this->netStock($variant->id));

    $this->service->delete($doc, $user->id); // confirm the actual reversal entry point

    $this->assertSame(0, $this->netStock($variant->id));
}

private function netStock(int $variantId): int
{
    return (int) StockMovement::where('product_variant_id', $variantId)
        ->selectRaw("COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END), 0) as net")
        ->value('net');
}
```

`netStock()` deliberately mirrors the production expression in `StockController::variants()` lines 91–96. If the two ever disagree, that is the bug you want surfaced.

Note the `SUM(movements) === 0` assertion is the whole point: it is the invariant that makes the ledger trustworthy. Write it as a helper and call it from every reversal test.

One of these tests will fail on `adjustment`, because adjustment is unconditionally mapped to `TYPE_IN`. That failure is correct and is the subject of `05-signed-adjustment-documents.md`. Mark it `$this->markTestIncomplete()` with a pointer to file 05 rather than asserting the broken behaviour — asserting it would lock the bug in.

### 2. Money formula tests (~10 tests)

There is exactly one money formula today: `ShipmentItemResource::computeTotal()` (`app/Http/Resources/ShipmentItemResource.php` lines 48–63):

```php
if ($unit === 'm2') {
    $sqm = $size->length * $size->width * $qty / 10000.0;
    return round($price * $sqm, 2);
}
return round($price * $qty, 2);
```

One test per rounding boundary, asserting the invoice figure and the ledger figure agree to the cent. Boundaries worth pinning:

- half-cent up: a `price × sqm` landing on `x.xx5` (PHP `round()` is half-away-from-zero; assert the actual chosen behaviour)
- a repeating decimal: 200×300 cm at `1/3` of a dollar
- `piece` unit vs `m2` unit for the same numbers
- quantity 0 and price 0
- a large shipment where per-line rounding and total rounding diverge — sum of rounded lines vs rounded sum of lines. This is the classic cent leak. Assert which one the invoice PDF uses and which one `ClientDebitService` uses, and that they match.

That last one is the test that matters. `resources/views/pdf/shipment_hisob_faktura.blade.php` line 284 renders `Jami summa`; whatever produces that number must equal what the debit ledger charges the client. If they differ by a cent per line across a 500-carpet shipment, that is $5 of permanent drift per shipment.

These tests must be written **after** the Phase 1 single-money-formula work, or rewritten with it. Coordinate — see Depends on.

### 3. Route smoke test (~15 tests, one data provider)

This is the highest value per line in the whole suite. `php artisan route:list --path=api` currently returns **124 routes**. Hit every one and assert it is not a 5xx.

```php
class RouteSmokeTest extends TestCase
{
    use RefreshDatabase;

    public static function routeProvider(): array
    {
        return collect(Route::getRoutes())
            ->filter(fn ($r) => str_starts_with($r->uri(), 'api/'))
            ->flatMap(fn ($r) => collect($r->methods())
                ->reject(fn ($m) => in_array($m, ['HEAD', 'OPTIONS'], true))
                ->map(fn ($m) => [$m, $r->uri(), $r->getName()]))
            ->values()
            ->mapWithKeys(fn ($x) => ["{$x[0]} {$x[1]}" => $x])
            ->all();
    }

    #[DataProvider('routeProvider')]
    public function test_route_does_not_500(string $method, string $uri, ?string $name): void
    {
        $user = User::factory()->create(['role' => ['admin']]); // role is JSON — see 2026_05_04_000001
        $url  = '/' . preg_replace('/\{[^}]+\}/', '1', $uri);

        $response = $this->actingAs($user, 'sanctum')->json($method, $url);

        $this->assertLessThan(
            500,
            $response->status(),
            "{$method} {$uri} ({$name}) returned {$response->status()}"
        );
    }
}
```

Substituting `1` for every route parameter means most routes return 404 or 422 — that is fine and intended. A 2xx/4xx means the code ran; a 5xx means it did not compile or blew up. The `DashboardController` bug is a 500 with no parameters at all, so it is caught on the first run.

Seed a minimal fixture set (one user, one client, one product/colour/size/variant with id 1) so the `{id}` = 1 routes reach real logic rather than 404ing at route-model binding. That upgrades the smoke test from "does it compile" to "does the happy path run", which is where the warehouse update bug lives.

Do not assert exact status codes per route in the provider. The moment you do, the test becomes a maintenance burden and people delete it. `< 500` is the contract.

### 4. GitHub Actions workflow

Write to `/.github/workflows/ci.yml` (repository root):

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      mysql:
        image: mysql:8.0
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: tgc_testing
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -h 127.0.0.1 -uroot -proot"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=10

    defaults:
      run:
        working-directory: tgc_backend

    steps:
      - uses: actions/checkout@v4

      - name: Set up PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, pdo_mysql, bcmath, gd, zip, intl
          coverage: none

      - name: Cache Composer packages
        uses: actions/cache@v4
        with:
          path: tgc_backend/vendor
          key: composer-${{ hashFiles('tgc_backend/composer.lock') }}
          restore-keys: composer-

      - name: Install dependencies
        run: composer install --prefer-dist --no-interaction --no-progress

      - name: Prepare environment
        run: |
          cp .env.example .env
          php artisan key:generate

      - name: Wait for MySQL
        run: |
          for i in {1..30}; do
            mysqladmin ping -h 127.0.0.1 -P 3306 -uroot -proot --silent && exit 0
            sleep 2
          done
          echo "MySQL did not become ready" && exit 1

      - name: Run migrations
        env:
          DB_CONNECTION: mysql
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_DATABASE: tgc_testing
          DB_USERNAME: root
          DB_PASSWORD: root
        run: php artisan migrate --force

      - name: Run tests
        env:
          DB_CONNECTION: mysql
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_DATABASE: tgc_testing
          DB_USERNAME: root
          DB_PASSWORD: root
        run: php artisan test
```

PHP version comes from `composer.json` line 9 (`"php": "^8.3"`); the framework is Laravel 13.1.1. `composer.json` already defines a `test` script (line 49) that runs `config:clear` then `artisan test` — `php artisan test` above is equivalent and skips a redundant clear.

Do not add a linter, static analysis, or a deploy step in this pass. A CI that fails for style reasons on week one gets switched off.

## How to verify

1. `cd tgc_backend && mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS tgc_testing" && php artisan test` — migrations complete, suite green.
2. Deliberately reintroduce the Dashboard bug: comment out the `StockMovement` import fix in `DashboardController`. Run `php artisan test --filter=RouteSmokeTest`. It must fail on `GET api/v1/dashboard/stats`. Restore.
3. Deliberately delete the `items.*.product_color_id` rule from `StoreWarehouseDocumentRequest`. The warehouse smoke/ledger test must fail. Restore.
4. Open a pull request with a trivial change. The Actions run must appear, go green, and take under about five minutes.
5. Push a commit that breaks a route on purpose. The PR must go red.

Steps 2 and 3 are not optional. A test suite that has never been seen to fail is not known to test anything.

## Rollback

Delete `/.github/workflows/ci.yml` and the new test files; revert `phpunit.xml`. Nothing under `app/` changes, so there is nothing to roll back on the live server. CI failure never blocks a deploy unless you add a branch protection rule — do not add one until the suite has been green for a week.

## Depends on / blocks

- **Depends on Phase 0** — the Dashboard and warehouse-update fixes should land first, otherwise the suite is red from the first commit and people learn to ignore it. Alternatively land the smoke test first, watch it go red, and use that as the Phase 0 bug report. Either order works; decide deliberately.
- **The money tests depend on Phase 1** (single money formula). If Phase 1 has not landed, write the ledger and smoke suites now and defer the money suite — do not write money tests against a formula you are about to replace.
- **Blocks everything else in Phase 3.** Files 02–08 all change stock, money, or production semantics on a live system with no tests. This file is what makes the rest safe to attempt. Do it first.
- Not blocked by Phase 2. The suite tests current behaviour and will need extension when `production_events` lands.
