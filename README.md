# وفّر — Waffir

Track the official price of essential goods against what shops actually charge.

A Flutter application backed by a Laravel 12 REST API on PostgreSQL 16.

```
Flutter app  ──▶  REST /api/v1  ──▶  Laravel 12  ──▶  PostgreSQL 16
```

| | |
|---|---|
| App | Flutter 3.44 · Provider · Dio · flutter_secure_storage · SharedPreferences · Arabic RTL |
| API | Laravel 12 · PHP 8.3 · Sanctum access tokens + rotating refresh tokens |
| Database | PostgreSQL 16 — **the only supported database**, in development, testing and production |
| Analytics | A Python reference implementation of the pricing algorithm (optional; the app never depends on it) |

Documentation:

* [`docs/FINAL_API_CONTRACT.md`](docs/FINAL_API_CONTRACT.md) — the authoritative API reference
* [`docs/openapi.yaml`](docs/openapi.yaml) · [`docs/waffir.postman_collection.json`](docs/waffir.postman_collection.json)
* [`docs/IMPLEMENTATION_AUDIT.md`](docs/IMPLEMENTATION_AUDIT.md) — what the app looked like before, and what changed
* [`docs/IMPLEMENTATION_REPORT.md`](docs/IMPLEMENTATION_REPORT.md) — architecture, schema, test results
* [`docs/MOCK_REMOVAL_REPORT.md`](docs/MOCK_REMOVAL_REPORT.md) — where every piece of mock data went

---

## 1. Start PostgreSQL

### With Docker

```bash
docker compose up -d postgres
```

This creates the `waffir` database, the `waffir` role, and the separate
`waffir_test` database used by the test suite.

### Without Docker

Install PostgreSQL 16, then:

```bash
createuser --pwprompt waffir           # password: waffir_dev_password
createdb -O waffir -E UTF8 waffir
createdb -O waffir -E UTF8 waffir_test
```

Any PostgreSQL 16 instance works, including a portable binary install — nothing
in the project requires administrator rights.

## 2. Start Laravel

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate:fresh --seed
php artisan serve --host=0.0.0.0 --port=8000
```

`--host=0.0.0.0` matters: it is what lets a phone reach the API.

Check it:

```bash
curl http://127.0.0.1:8000/api/v1/health
```

`"database_driver": "pgsql"` and `"database": "up"` mean everything is wired up.

## 3. Run the Flutter app

```bash
flutter pub get
```

### On a physical Android phone over USB — recommended

Forward the phone's own port 8000 to the laptop; no Wi-Fi, no IP address and no
firewall rule involved:

```bash
adb reverse tcp:8000 tcp:8000
```

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Re-run the `adb reverse` command after replugging the cable.

### On a physical phone over Wi-Fi

Both devices must be on the same network. Find the laptop's LAN address
(`ipconfig` on Windows, `ip addr` on Linux/macOS), then:

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
```

Two things to check if the app cannot connect:

1. the laptop firewall must allow inbound TCP 8000;
2. Android blocks plain HTTP by default — add your LAN address to
   `android/app/src/main/res/xml/network_security_config.xml`, which already
   allows `127.0.0.1`, `localhost` and `10.0.2.2`.

### On the Android emulator

```bash
flutter run \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` is how the emulator addresses the host machine.

### On Windows, web or desktop

```bash
flutter run -d windows \
  --dart-define=USE_MOCK_DATA=false \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

### Offline UI work

```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

Mock mode is **off by default**. A build without the flag always talks to the
real API, and a failing request is shown as a real error — it never silently
falls back to sample data.

---

## 4. Development credentials

> **Development only.** Seeded by `DevAccountsSeeder`. Never seed these into a
> real deployment.

| Role | Phone | Email | Password |
|---|---|---|---|
| User | `0990000001` | — | `Password123!` |
| Admin (role 1) | `0990000002` | `admin@waffir.local` | `Password123!` |
| Super admin (role 2) | `0990000003` | `superadmin@waffir.local` | `Password123!` |

The admin panel is reached from "دخول الإدارة" on the welcome screen and accepts
either the phone number or the email as the username.

## 5. OTP in development

No SMS gateway is needed. `WAFFIR_SMS_DRIVER=log` writes the code to
`backend/storage/logs/laravel.log`:

```bash
tail -f backend/storage/logs/laravel.log | grep '\[SMS\]'
```

For convenience, `OTP_TEST_CODE=123456` in `.env` makes **`123456` always
valid** — but only when `APP_ENV` is `local` or `testing`. In any other
environment the setting is ignored and a real random code is required.

OTP behaviour, all configurable in `.env`: 6 digits, 10-minute expiry, 5
verification attempts, 60-second resend cooldown, and rate limits on every
send and verify route.

---

## 6. Tests

```bash
cd backend
php artisan test          # 90 tests, against PostgreSQL (waffir_test)
```

```bash
flutter analyze           # 0 errors, 0 warnings
flutter test              # 21 tests
```

End-to-end against a running backend:

```bash
cd backend
./scripts/smoke-test.sh                                  # 40 checks
./scripts/smoke-test.sh http://192.168.1.10:8000/api/v1  # or a specific host
```

Optional Python reference implementation:

```bash
cd backend/analytics
python test_waffir_analytics.py       # 17 tests
python compare_with_php.py            # PHP vs Python, 10 cases
```

The database tests run against **PostgreSQL**, not SQLite — the schema relies on
PostgreSQL CHECK constraints, `ILIKE` and `NUMERIC`, none of which SQLite would
enforce the same way.

---

## 7. Layout

```
.
├── android/ ios/ web/          Flutter platform shells
├── lib/                        Flutter application
│   ├── core/                   config, networking, providers, theme, widgets
│   ├── features/               auth, user, admin, legal
│   └── models/                 API models
├── test/                       Flutter tests
├── backend/                    Laravel 12 API
│   ├── app/
│   │   ├── Http/               controllers, requests, resources, middleware
│   │   ├── Models/             the ERD
│   │   ├── Services/           PriceAggregationService, OtpService, TokenService
│   │   ├── Sms/                SmsSenderInterface + log driver
│   │   └── Support/            ApiResponse envelope, Arabic messages
│   ├── database/               migrations, factories, seeders
│   ├── routes/api.php          every endpoint, with its role requirement
│   ├── analytics/              Python reference implementation
│   ├── scripts/                smoke test, Postman generator, data extractor
│   └── tests/                  Feature + Unit
├── docs/                       API contract, audit, reports, OpenAPI, Postman
├── docker-compose.yml          PostgreSQL 16
└── schema.txt                  the academic schema this project is built from
```

## 8. Configuration reference

Everything lives in `backend/.env` (see `.env.example`):

| Variable | Default | Meaning |
|---|---|---|
| `DB_CONNECTION` | `pgsql` | Never change this |
| `SANCTUM_TOKEN_EXPIRATION` | `60` | Access-token lifetime, minutes |
| `WAFFIR_REFRESH_TOKEN_DAYS` | `30` | Refresh-token lifetime |
| `WAFFIR_OTP_LENGTH` | `6` | OTP digits |
| `WAFFIR_OTP_TTL_MINUTES` | `10` | OTP validity |
| `WAFFIR_OTP_MAX_ATTEMPTS` | `5` | Verifications before the code dies |
| `WAFFIR_OTP_RESEND_COOLDOWN_SECONDS` | `60` | Resend cooldown |
| `WAFFIR_SMS_DRIVER` | `log` | `log` or `null` |
| `OTP_TEST_CODE` | `123456` | Local/testing only |
| `WAFFIR_PRICE_FRESHNESS_DAYS` | `30` | How old a submission may be |
| `WAFFIR_PRICE_MAD_THRESHOLD` | `3.5` | Outlier cut-off |
| `WAFFIR_PRICE_MIN_SAMPLES_FOR_FILTER` | `5` | Below this, nothing is filtered |
| `WAFFIR_CORS_ALLOWED_ORIGINS` | `*` | Comma-separated list in production |
