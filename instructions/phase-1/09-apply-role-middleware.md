# 09 — Fix the role middleware, audit who uses what, then apply it

`EnsureRole` is registered but applied to zero routes. Every authenticated user can call every endpoint. The middleware is also broken — it compares an array against strings and would reject everyone, including admins.

**Severity: High / Effort: 3d / Safe on live: NO. Applying this blind will lock out staff mid-shift. The audit is the work; the code is an afternoon.**

## Why this matters

### It is registered and never used

`bootstrap/app.php:16-20`:

```php
$middleware->alias([
    'role'      => \App\Http\Middleware\EnsureRole::class,
    // Used by the admin web panel to verify the `admin` role after session auth
    'web_admin' => \App\Http\Middleware\EnsureWebAdmin::class,
]);
```

The alias exists. Now grep for anything using it:

```bash
grep -rn "role:" routes/
```

**Zero results. Verified.** `routes/api.php` puts everything behind `Route::middleware('auth:sanctum')` (line 55) and nothing else. Authentication without authorisation: the system checks *who you are* and never *what you may do*.

There is no second line of defence. Every `FormRequest` returns `true` from `authorize()` — verified across all 26 request classes. There are no policies (`app/Policies/` does not exist).

So: a `label_manager` — whose job is printing labels — can `POST /api/v1/payments` to record a $50,000 payment against any client, `DELETE /api/v1/payments/{id}` to make one disappear (step 06), `POST /api/v1/shipments` to ship goods to anyone, and `DELETE /api/v1/raw-materials/{id}`. `User::ROLES` (lines 27-37) defines nine distinct roles. The system distinguishes none of them.

The only role check that works anywhere is `EnsureWebAdmin` (`app/Http/Middleware/EnsureWebAdmin.php:24`), guarding the admin web panel. The entire API has nothing.

### And the middleware would reject everyone

`app/Http/Middleware/EnsureRole.php:17-27`:

```php
public function handle(Request $request, Closure $next, string ...$roles): Response
{
    if (! in_array($request->user()?->role, $roles, true)) {
        return response()->json(
            ['message' => 'Forbidden. Insufficient role.'],
            Response::HTTP_FORBIDDEN,
        );
    }

    return $next($request);
}
```

`$roles` is a list of strings from the route: `['admin', 'warehouse_manager']`. And `$request->user()->role` is — since `2026_05_04_000001_*` changed the column to JSON (line 17) and `User` casts it to `'array'` (`app/Models/User.php:57`) — **an array**: `['admin']`.

So `in_array(['admin'], ['admin', 'warehouse_manager'], true)` asks "is the *array* `['admin']` one of the *strings* in this list?" With `strict: true`, an array never equals a string. **It returns `false`. Always. For everyone, including admins.**

Apply this middleware as it stands and every guarded route returns 403 to every user. The migration that made `role` a JSON array (`UPDATE users SET role = JSON_ARRAY(role)`, line 13) broke this middleware, and nobody noticed **because it was never applied to anything**. Two bugs cancelling out: a middleware that rejects everyone, used nowhere.

`User` already has the correct helpers — `hasRole()` (line 66), `hasAnyRole()` (line 74), `getRoles()` (line 82), all guarded with `is_array($this->role)`. `EnsureWebAdmin` uses `hasRole()` properly. `EnsureRole` predates the JSON migration and was never updated.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Http/Middleware/EnsureRole.php` | 17-27 | Fix `handle()`. |
| `routes/api.php` | 55+ | Apply — **only after the audit**. |

## The change

### Stage 1 — Fix the middleware (safe; it is applied to nothing)

```php
// current — line 19
if (! in_array($request->user()?->role, $roles, true)) {

// intended
public function handle(Request $request, Closure $next, string ...$roles): Response
{
    $user = $request->user();

    if (! $user?->hasAnyRole($roles)) {
        return response()->json(
            ['message' => 'Forbidden. Insufficient role.'],
            Response::HTTP_FORBIDDEN,
        );
    }

    return $next($request);
}
```

`hasAnyRole()` (`User.php:74-77`) does `array_intersect($this->role, $roles)` with an `is_array` guard, which is exactly right for a JSON array column.

Consider whether **admin should bypass everything**. `EnsureWebAdmin` treats admin as the master key, and an admin who cannot reach a route because someone forgot to list `admin` in the middleware args is a support call:

```php
if ($user?->hasRole(User::ROLE_ADMIN)) {
    return $next($request);   // admin bypasses all role gates
}
```

I lean towards including it — it makes every route list shorter and prevents the most likely lockout. But it is a real security decision (admin becomes un-scopeable) and it is not mine to make. Ask, then write the answer in a comment.

This stage is **completely safe to deploy**. The middleware is applied to zero routes, so fixing it changes nothing at runtime. Ship it on its own, immediately.

### Stage 2 — Audit. This is the actual work.

**Do not skip to stage 3.** You are about to decide, for nine roles across roughly 60 endpoints, who may do what. Guess wrong on one and a warehouse manager cannot receive goods at 8am on a shipping day.

There are no tests to catch a wrong guess, no staging traffic that resembles production, and no spec. The only reliable source of truth is **what people actually do**.

**2a. Log real usage for at least two weeks.**

Two weeks, not one. It must cover a month-end, a shipping-heavy day, and whatever the factory's weekly rhythm is. Add a middleware that records rather than blocks — applied globally, blocking nothing:

```php
// app/Http/Middleware/LogRoleUsage.php — temporary, remove after the audit
public function handle(Request $request, Closure $next): Response
{
    $response = $next($request);

    if ($user = $request->user()) {
        Log::channel('role_audit')->info('api.access', [
            'user_id' => $user->id,
            'roles'   => $user->getRoles(),
            'method'  => $request->method(),
            'route'   => $request->route()?->getName() ?? $request->path(),
            'status'  => $response->getStatusCode(),
        ]);
    }

    return $response;
}
```

Log **after** `$next()` and record the status, so you can tell a successful call from one that already 404'd. A dedicated channel keeps it out of `laravel.log` and makes it easy to delete afterwards. Watch the disk — this logs every request.

Then aggregate:

```bash
# Which roles hit which routes, and how often
grep 'api.access' storage/logs/role_audit*.log \
  | jq -r '[(.context.roles | join("+")), .context.method, .context.route] | @tsv' \
  | sort | uniq -c | sort -rn
```

The output is a role × route matrix built from reality. **That table is the specification.** Everything else is a guess.

**2b. Read it with the people who use the system.**

The log tells you what happens, not what *should*. Both matter:

- A route only ever called by `admin` → probably admin-only. Or the one person who does it happens to be an admin, and their colleague will need it next month.
- A route called by `label_manager` that looks like it should be sales-only → either a real access problem you are about to fix, or a workflow you do not understand. **Ask before blocking it.**
- A route in the matrix with **zero** hits over two weeks → do not guess. Zero hits is not permission to lock it to admin; it may be quarterly work.

Take the matrix to whoever runs the factory floor. Go route by route on anything ambiguous. Write the decision down.

**2c. Watch for multi-role users.**

```sql
SELECT id, name, role FROM users WHERE JSON_LENGTH(role) > 1;
SELECT role, COUNT(*) FROM users GROUP BY role;
```

`role` is an array and `hasAnyRole` intersects, so a user with `['warehouse_manager', 'sales_manager']` passes a gate naming either. Check the real distribution — if most users hold several roles, the gates will be looser than they look on paper.

Also check for users with an **empty or null** role:

```sql
SELECT id, name, role FROM users WHERE role IS NULL OR JSON_LENGTH(role) = 0;
```

`hasAnyRole` returns `false` for those, so **every guarded route 403s for them**. If any such user exists and is active, fix their role data *before* stage 3, or you have found your first lockout.

### Stage 3 — Apply, per group, slowly

Only with the matrix in hand and the decisions signed off.

`routes/api.php` is already organised into commented groups — clients around line 108, warehouse documents at 125, stock at 136, shipments at 150, production batches at 160. That structure is your unit of rollout.

```php
// Example only — the matrix decides the actual roles, not this file.
Route::middleware('role:admin,sales_manager')->group(function (): void {
    Route::apiResource('clients', ClientController::class);
    Route::get('clients/debits', [ClientDebitController::class, 'index']);
});
```

**One group per deploy.** Start with the least dangerous — an area with few users and no shift-critical path. Watch for 403s for a day. Then the next.

Do **not** apply it to `Route::middleware('auth:sanctum')` wholesale. A single deploy that gates everything is the lockout scenario, and rolling it back means finding which of sixty routes is wrong while the factory waits.

**Ship the kill switch with the first group:**

```php
// config/auth_roles.php
return [
    'enforce' => env('ROLE_MIDDLEWARE_ENFORCE', false),
];
```

```php
// EnsureRole::handle, after resolving $user
if (! config('auth_roles.enforce', false)) {
    if (! $user?->hasAnyRole($roles)) {
        Log::warning('role.would_block', [
            'user_id'        => $user?->id,
            'roles'          => $user?->getRoles(),
            'required'       => $roles,
            'route'          => $request->route()?->getName() ?? $request->path(),
        ]);
    }

    return $next($request);   // log only; nobody is blocked
}
```

This is the same pattern as step 02, and here it matters more: **role mistakes surface as a person unable to do their job, immediately, with no workaround.** A week of `role.would_block` with the routes applied but not enforced tells you exactly who you are about to lock out — from production traffic, not from a guess. Every hit is either a permission you got wrong or an access problem you are about to correct. **Know which, for every one, before flipping.**

`ROLE_MIDDLEWARE_ENFORCE=false` + `php artisan config:clear` restores access in seconds without a deploy. Given no tests and a live factory, that switch is the difference between a bad afternoon and a stopped shift.

### On `authorize()` and policies

Every `FormRequest` returns `true` from `authorize()`. Route middleware is the right layer for coarse "may this role reach this endpoint" checks, and it is enough for phase 1.

It is **not** enough for row-level rules — "a sales manager may only see their own clients". That needs policies, and it is a bigger design question about whether the factory even wants that. **Out of scope here.** Note it and move on; do not let it expand this step.

## How to verify

No test suite. Staging, restored from a production dump, with **real user rows** so the role data is realistic.

**1. Prove the current middleware is broken.** Before fixing, apply it to one throwaway route on staging:

```php
Route::get('role-test', fn () => response()->json(['ok' => true]))
    ->middleware('role:admin');
```

Call it as an **admin**:

```bash
curl https://staging/api/v1/role-test -H "Authorization: Bearer $ADMIN_TOKEN"
```

**403.** An admin, rejected by `role:admin`. That is the array-vs-string bug, confirmed from the outside. Do not skip this — it is what makes the rest of the step obviously necessary.

**2. After the fix**, same route:
- Admin token → **200**
- `label_manager` token → **403** with `Forbidden. Insufficient role.`
- Multi-role user holding `admin` among others → **200**
- User with `role = '[]'` → **403** (and note this is the lockout case from 2c)
- No token → **401** from `auth:sanctum`, before `EnsureRole` runs

Then delete the throwaway route.

**3. Confirm stage 1 is inert.** After deploying the middleware fix with no routes using it:

```bash
grep -rn "role:" routes/
```

Still zero. Smoke-test the app: everything works exactly as before. **The fix must be observable nowhere.** If any behaviour changed, something is applying the middleware and you did not know about it.

**4. During log-only mode**, per group:

```bash
grep 'role.would_block' storage/logs/laravel.log \
  | jq -r '[.context.user_id, (.context.roles|join("+")), .context.route] | @tsv' \
  | sort | uniq -c | sort -rn
```

**Every distinct line must be understood before enforcing.** A `warehouse_manager` blocked from a warehouse route means your matrix is wrong. A `label_manager` blocked from `POST /payments` means the gate is working.

**5. After enforcing a group**, verify with real tokens for each role that legitimately uses it. Not admin tokens — **the actual roles**. An admin bypass (if you added one) means admin testing proves nothing:

```bash
# For each role in the matrix for this group
curl -X POST https://staging/api/v1/warehouse-documents \
  -H "Authorization: Bearer $WAREHOUSE_MANAGER_TOKEN" ... # → 201, must still work
```

**6. Drive the client app as each role.** Log into the Flutter app on staging as a warehouse manager and complete a full receive-to-warehouse flow. Then as a sales manager, a full order-to-shipment flow. **A 403 in the middle of a workflow is what you are trying to prevent, and only the real app will show you the screen where it happens.** Check the app handles 403 gracefully at all — if it shows a blank screen or a crash rather than a message, fix that first.

**7. Before each production deploy**, check who is about to be affected:

```sql
SELECT role, COUNT(*) AS users FROM users GROUP BY role;
```

Cross-reference against the group you are gating. If a role with many active users is about to lose access to something they use daily, you already know from the logs — but look again.

## Rollback

- **Kill switch:** `ROLE_MIDDLEWARE_ENFORCE=false` + `php artisan config:clear`. Seconds, no deploy. **This is the primary rollback and the reason the flag exists.**
- **Code:** `git revert` the route group. No migration, nothing persisted.
- **Stage 1 alone:** nothing to roll back; it changes no behaviour.

**If staff report 403s during a shift: flip the switch first, diagnose after.** Do not debug a permission matrix while a factory waits. The system has had no authorisation for its entire life; one more day costs nothing next to a stopped line.

Deploy each group **at the start of a quiet period**, never on a Friday, never mid-shift. Have the switch command ready in your shell before you deploy, not after someone calls.

## Depends on / blocks

- **Depends on:** nothing technically. **Sequence it last in phase 1.** Steps 01-08 change what the system computes; this changes who can reach it. If both land together and someone reports a problem, you cannot tell whether the number is wrong or they were blocked from fixing it. Let 01-08 settle first.
- **Blocks:** nothing.
- **Split the effort honestly.** Stage 1 is an afternoon and ships immediately. Stages 2-3 are the remaining ~2.5 days, and **most of that is the audit, not the code**. If the schedule squeezes, ship stage 1 and let the audit take the time it needs. A rushed permission matrix is worse than none — it locks out real people while giving false confidence that access is controlled.
- **Out of scope:** row-level policies, `authorize()` on FormRequests, and any per-record ownership rules. Phase-2 or later, if wanted at all.
