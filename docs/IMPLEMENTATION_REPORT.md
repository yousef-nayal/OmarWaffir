# Implementation report — Waffir

Flutter + Laravel 12 + PostgreSQL 16, running end to end.

---

## 1. Architecture

```
┌────────────────────────┐
│  Flutter (Android)     │  Provider · Dio · secure storage · SharedPreferences
│  Arabic RTL, unchanged │
└──────────┬─────────────┘
           │  HTTPS/HTTP  ·  Bearer access token  ·  Accept-Language: ar
           ▼
┌────────────────────────┐
│  Laravel 12  /api/v1   │  Sanctum + rotating refresh tokens
│  68 routes             │  Form Requests · API Resources · role middleware
│                        │  PriceAggregationService · OtpService · TokenService
└──────────┬─────────────┘
           │  PDO pgsql
           ▼
┌────────────────────────┐
│  PostgreSQL 16         │  16 tables · CHECK constraints · RESTRICT FKs
└────────────────────────┘

           ┌───────────────────────────────────────────┐
           │  backend/analytics (Python, optional)      │
           │  reference implementation of the algorithm │
           └───────────────────────────────────────────┘
```

Nothing in the request path depends on Python. The app never falls back to
sample data when the API is unreachable — a network failure is a real error.

## 2. PostgreSQL schema

16 tables. The academic ERD is preserved; the rest are operational.

**Core (from the ERD)**

| Table | Notes |
|---|---|
| `sectors` | soft deletes, unique name |
| `locations` | `sector_id` FK, `district` canonical, unique `(sector_id, district)` |
| `stores` | `location_id` FK, `is_verified`, `submitted_by_user_id`, soft deletes |
| `products` | `name`, `category` only — **no price columns** |
| `units`, `brands` | unique names |
| `users` | `location_id`, `phone_number` unique, `email` unique nullable, `role` smallint `CHECK (role IN (0,1,2))`, `is_active`, `phone_verified_at`, soft deletes |
| `auth_otps` | `otp_hash`, `attempts`, `is_used`, `expires_at`, `verified_at`, `CHECK` on `purpose` |
| `official_prices` | append-only history, `NUMERIC(12,3)` amount, `NUMERIC(18,2)` price, `created_by` |
| `prices` | `user/store/product/unit/brand`, amount, price — **no status column** |
| `ratings` | `value BOOLEAN`, `UNIQUE (user_id, price_id)` |
| `reports` | `CHECK` on the three Arabic types; `CHECK` that only `معلومات غير صحيحة` may carry a description |

**Operational**

| Table | Purpose |
|---|---|
| `refresh_tokens` | UUID pk, SHA-256 `token_hash`, `expires_at`, `revoked_at`, `last_used_at`, user agent, IP |
| `activity_logs` | feeds `GET /admin/recent-activity` |
| `notifications` | Laravel database notifications |
| `personal_access_tokens` | Sanctum |
| `cache`, `jobs`, `sessions`, `password_reset_tokens` | framework |

**Types** — ids `BIGINT`; money `NUMERIC(18,2)`; amounts `NUMERIC(12,3)`;
booleans `BOOLEAN`; timestamps returned as ISO-8601 UTC with `Z`.

**Indexes** — `prices(product_id, created_at)`, `prices(store_id, created_at)`,
`prices(user_id, created_at)`, `ratings(price_id)`, `ratings(user_id, price_id)`
unique, `reports(price_id)`, `reports(type)`, `stores(location_id)`,
`stores(is_verified)`, `locations(sector_id)`,
`official_prices(product_id, unit_id, created_at)`, `users(phone_number)`,
`users(role)`, `users(location_id)`, `activity_logs(type, created_at)`.

**Delete policy** — foreign keys are `RESTRICT`, and administrative deletes of
users, stores and products are **soft** deletes, so historic prices survive.
Ratings and reports cascade with the price they belong to, which is what makes
deleting a wrong price a clean review action.

## 3. Laravel structure

```
app/
  Http/
    Controllers/Api/V1/   Auth, Product, Store, Price, Report,
                          OfficialPrice, Catalog, Notification, Health,
                          Admin/{AdminUser,Dashboard}
    Requests/             Auth/* (9) + StoreReportRequest
    Resources/            12 resources - the only place response shapes exist
    Middleware/           EnsureRole, EnsureActiveUser, ForceJsonResponse
  Models/                 14 Eloquent models
  Services/               PriceAggregationService, OtpService, TokenService,
                          ActivityLogger
  Sms/                    SmsSenderInterface, LogSmsSender, NullSmsSender
  Support/                ApiResponse (the envelope), Msg (Arabic messages)
  Notifications/          OfficialPriceChanged
config/waffir.php         every tunable in one file
lang/ar/validation.php    Arabic validation messages
routes/api.php           68 routes grouped by required role
```

`bootstrap/app.php` renders **every** API exception into the envelope with an
Arabic message, so a raw Laravel stack trace can never reach the app.

## 4. API endpoints

68 routes under `/api/v1`, fully specified in
[`FINAL_API_CONTRACT.md`](FINAL_API_CONTRACT.md),
[`openapi.yaml`](openapi.yaml) and
[`waffir.postman_collection.json`](waffir.postman_collection.json).

| Group | Count | Auth |
|---|---|---|
| Health | 1 | public |
| Auth | 13 | mixed |
| Catalog (sectors, locations, units, brands) | 16 | GET public, writes role 1 |
| Products | 7 | reads public, writes role 1 |
| Stores | 6 | reads public, create user, rest role 1 |
| Prices | 4 | create/vote user, list/delete role 1 |
| Reports | 3 | create user, list/delete role 1 |
| Official prices | 5 | reads public, writes role 1 |
| Notifications | 4 | user |
| Admin (users + dashboard) | 9 | role 1, `role` change role 2 |

## 5. Authentication lifecycle

```
register ─▶ unverified account + OTP, NO tokens
        └─▶ verify-otp ─▶ access_token (60 min) + refresh_token (30 d) + user
login    ─▶ access_token + refresh_token + user
refresh  ─▶ new pair; the presented refresh token is revoked at once
logout   ─▶ access token deleted, its refresh session revoked
```

* refresh tokens are random, stored only as SHA-256, rotated every time
* password reset revokes **every** session; changing it from settings revokes
  every **other** session, so the device doing it stays signed in
* blocking a user deletes their tokens immediately
* `/auth/me` returns everything needed to restore a session, including
  `location_id` and the three contribution counters

## 6. Role matrix

| Capability | 0 user | 1 admin | 2 super admin |
|---|:--:|:--:|:--:|
| Browse products, stores, official prices, history | ✓ | ✓ | ✓ |
| Submit a price · rate · report · suggest a store | ✓ | ✓ | ✓ |
| Update own profile and location | ✓ | ✓ | ✓ |
| Review and delete prices / reports | | ✓ | ✓ |
| Verify, edit, delete stores | | ✓ | ✓ |
| Manage products, units, brands, sectors, locations | | ✓ | ✓ |
| Manage official prices and their history | | ✓ | ✓ |
| Dashboard and recent activity | | ✓ | ✓ |
| Manage role-0 users (create, edit, block, delete) | | ✓ | ✓ |
| Create, edit or delete an **admin** | | | ✓ |
| Change any role | | | ✓ |

Extra guards: nobody may act on their own account through the admin endpoints,
and the last super admin can be neither deleted nor demoted.

## 7. OTP

6 digits · 10-minute expiry · 5 verification attempts · 60-second resend
cooldown · rate limits on send and verify — all configurable.

The code is bcrypt-hashed before storage and consumed inside a transaction.
`SmsSenderInterface` has a log driver, so the project runs without an SMS
gateway; `OTP_TEST_CODE=123456` is honoured **only** when `APP_ENV` is `local`
or `testing`.

Purposes: `registration`, `password_reset`, `password_change`.

## 8. Representative price algorithm

`app/Services/PriceAggregationService.php`:

1. price events from the last 30 days
2. restricted to stores in the requested `location_id`, when given
3. only submissions in the same unit as the current official price
4. normalised to one unit — `price / amount`
5. values ≤ 0 dropped
6. outlier rejection
   * < 5 samples → keep everything
   * `|0.6745·(x − median)/MAD| > 3.5` → reject
   * `MAD = 0` → IQR fence at `1.5·IQR`
   * `IQR = 0` too → mean absolute deviation, same threshold
   * a filter that would empty the set is discarded
7. `real_price = median(kept) × official_amount`, `avg_price = mean × amount`
8. `change_percent = (real − official)/official × 100` when both > 0
9. `is_price_up = real >= official`
10. nothing usable → both prices are 0

Aggregating a page of products takes a fixed number of queries, and the service
is isolated so caching can be added later without touching the controllers.

`backend/analytics/` holds a dependency-free Python implementation of the same
algorithm; `compare_with_php.py` verifies the two agree on 10 cases including
every fallback branch.

## 9. Flutter changes

Deliberately minimal — **no layout, colour, navigation or RTL change**.

| File | Change |
|---|---|
| `core/config/app_config.dart` | `useMockData` is a dart-define defaulting to `false` |
| `core/network/api_client.dart` | refresh interceptor reads the `{success, data}` envelope |
| `features/auth/data/auth_service.dart` | `register()` returns `RegistrationResult` and stores no tokens; `verifyOtp()` returns `AuthResult` and stores them; profile accepts `locationId`; change-password takes an OTP |
| `core/utils/app_provider.dart` | `selectedLocationId` persisted and synced; registration stays unauthenticated; admin decided by `roleLevel`; `totalProducts`; `loadCategories()` |
| `models/models.dart` | `UserModel.locationId`, `StoreModel.locationId`/`sectorId`, `ProductModel.unitId`/`amount` |
| `core/network/services/product_service.dart` | `location_id` on list and detail; `getCategories()` |
| `features/user/screens/home_screen.dart` | real stat chips; location picker resolves an id and reloads |
| `features/user/screens/products_screen.dart` | categories from the API, server-side filtering, OTP password change |
| `features/auth/.../password_recovery_screens.dart` | settings path uses the change-password endpoints |
| `android/.../AndroidManifest.xml` + `res/xml/network_security_config.xml` | `INTERNET`; cleartext for development hosts only |
| `android/gradle.properties` | Kotlin incremental compilation disabled (toolchain bug) |

## 10. Removed mock paths

Full accounting in [`MOCK_REMOVAL_REPORT.md`](MOCK_REMOVAL_REPORT.md).

* 15 `MockData` call sites — all already behind the switch, kept for offline UI
  work, unreachable in a default build
* home header stats hardcoded to `16` / `8` / `24` — **replaced** with real
  values
* product category list that matched no database row — **replaced** with
  `GET /products/categories`
* no fake successes: every write awaits a real request

## 11. Tests executed

| Suite | Command | Result |
|---|---|---|
| Backend (PostgreSQL) | `php artisan test` | **90 passed**, 407 assertions |
| Flutter analyzer | `flutter analyze` | **0 errors, 0 warnings** (42 style infos) |
| Flutter | `flutter test` | **21 passed** |
| End-to-end | `./scripts/smoke-test.sh` | **40/40 checks passed** |
| Python reference | `python test_waffir_analytics.py` | **17 passed** |
| PHP vs Python | `python compare_with_php.py` | **10/10 cases match** |
| Migrations + seed | `php artisan migrate:fresh --seed` | OK |
| Routes | `php artisan route:list` | 68 routes |

Backend coverage: authentication (registration, OTP correct/wrong/expired,
login, unverified, blocked, admin login, refresh rotation, hashed storage,
logout, reset, change), authorisation (the full role matrix, self-modification,
last super admin), products (pagination, search, category, location-aware
values, amount normalisation, freshness window, newest official row),
stores (unverified submission, verification, filters, delete policy),
prices (submission, spoofed `user_id`, invalid relationships, voting rules,
self-vote, admin filters, cascade), reports (three types, conditional
description, payload, filters), official prices (current version, history,
notifications), dashboard (real counts, growth, division by zero,
authorisation), and the aggregation algorithm on its own.

## 12. Seed data

| Table | Rows |
|---|---|
| sectors | 5 |
| locations | 110 |
| units | 5 |
| brands | 8 |
| products | 20 |
| stores | 12 (2 unverified) |
| users | 9 |
| official_prices | 54 (3 versions per product — real history) |
| prices | 126 across every district |
| ratings | 108 |
| reports | 14 |
| activity_logs | 19 |

Reference data is generated from `schema.txt`, so the Arabic values match the
thesis and the district names the location picker uses.

## 13. Seed accounts — development only

| Role | Phone | Email | Password |
|---|---|---|---|
| User | `0990000001` | — | `Password123!` |
| Admin | `0990000002` | `admin@waffir.local` | `Password123!` |
| Super admin | `0990000003` | `superadmin@waffir.local` | `Password123!` |

Plus six ordinary contributors so submitted prices are not all by one person.
All are verified. **Never seed these into a real deployment.**

## 14. Local run commands

```bash
docker compose up -d postgres

cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

```bash
flutter pub get
adb reverse tcp:8000 tcp:8000          # physical phone over USB
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Emulator: `http://10.0.2.2:8000/api/v1`. Wi-Fi: the laptop's LAN address, which
also has to be added to `network_security_config.xml`. Full instructions in
[`../README.md`](../README.md).

## 15. Remaining limitations

1. **No real SMS gateway.** `LogSmsSender` writes the code to the log.
   Implementing `SmsSenderInterface` against a provider is the only change
   needed.
2. **No push notifications.** In-app notifications only, as scoped. There is no
   Firebase infrastructure in the project to build on.
3. **Notification fan-out is synchronous.** Publishing an official price
   notifies users in chunks inside the request. Fine at this scale; it should
   move to a queued job before a large user base.
4. **Aggregation is not cached.** Each product list recomputes from price rows.
   Query count is fixed and indexes cover it, but a cache layer behind
   `PriceAggregationService` is the natural next step.
5. **Admin location filters still use block/district names in some screens.**
   The server accepts ids everywhere and the app resolves them for the paths
   that matter; the remaining admin dropdowns could pass ids too.
6. **`AleppoBlocks` is a local list.** Kept deliberately (the picker must work
   before a session exists), and always resolved to a real `locations.id`
   before anything is sent. A district added by an admin that is not in the
   local list will not appear in the picker until it is added there as well.
7. **Rate limits are per-IP defaults.** Reasonable for a demo; production should
   tune them and put the API behind a reverse proxy.
8. **Notification preferences are local.** The settings toggle is stored on the
   device, as the existing screen was designed.

## 16. Production deployment considerations

* `APP_DEBUG=false`, `APP_ENV=production`, a fresh `APP_KEY`, and
  `OTP_TEST_CODE` **removed** — the code path already refuses it outside
  local/testing, but do not ship the variable.
* HTTPS only. Then delete the development entries from
  `network_security_config.xml` and set `cleartextTrafficPermitted="false"`
  everywhere.
* Set `WAFFIR_CORS_ALLOWED_ORIGINS` to the real origins instead of `*`.
* Replace `LogSmsSender` with a real gateway; without it, no one can register.
* `php artisan config:cache route:cache view:cache`, and `composer install
  --no-dev --optimize-autoloader`.
* Move queues off `sync` (`QUEUE_CONNECTION=redis` or `database`) so the
  notification fan-out stops blocking requests.
* Managed PostgreSQL with automated backups; `waffir_test` is not needed there.
* Ship logs somewhere durable and watch the `[SMS]` channel for failures.
* Rotate the seeded credentials out — `DevAccountsSeeder` must not run in
  production. Create the first super admin manually.
