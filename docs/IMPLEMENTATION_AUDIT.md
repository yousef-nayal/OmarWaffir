# Implementation audit — Waffir

Written before the backend was implemented, from a full read of the Flutter
source. It records what the app actually did, where it disagreed with the
prose documentation, and what was going to change.

> Rule applied throughout: **the Flutter code is more authoritative than the old
> prose docs; the backend design decisions in the task brief override both.**

---

## 1. Current Flutter architecture

| Layer | Where | Notes |
|---|---|---|
| Entry point | `lib/main.dart` | `MultiProvider` with 7 providers, `MaterialApp` with a static route table, forced RTL, portrait lock |
| Config | `lib/core/config/app_config.dart` | Single `useMockData` constant |
| Networking | `lib/core/network/api_client.dart` | One Dio singleton, `_AuthInterceptor`, `flutter_secure_storage` for tokens |
| Envelope | `lib/core/network/api_response.dart` | `{success, data, message, pagination}` + `PaginationMeta` |
| Errors | `lib/core/network/api_exception.dart` | Maps Dio failures to Arabic messages by status code |
| Services | `lib/core/network/services/*` + `features/auth/data/auth_service.dart` | 6 services, all already written against a REST contract |
| State | `lib/core/utils/app_provider.dart` (1 963 lines) | `AppProvider` + 6 feature providers, every method already branching on `useMockData` |
| Models | `lib/models/models.dart` | 11 models with `fromJson`/`toJson` |
| Screens | `lib/features/**` | User shell (5 screens), admin shell (7 231 lines), auth + recovery |
| Reference data | `lib/core/constants/aleppo_blocks.dart` | The five official Aleppo blocks and their districts, extendable and persisted locally |

The structure was in good shape. The service layer was written against a REST
API that did not exist yet, and every provider already had a real branch beside
its mock branch. **The work was integration, not rewriting.**

## 2. Existing services and the endpoints they call

| Service | Endpoints |
|---|---|
| `AuthService` | `POST /auth/login`, `/auth/register`, `/auth/admin/login`, `/auth/logout`, `/auth/verify-otp`, `/auth/resend-otp`, `/auth/forgot-password`; `PUT /auth/profile`, `/auth/reset-password`, `/auth/change-password`; `GET /auth/me` |
| `ProductService` | `GET /products`, `/products/{id}`, `/products/{id}/prices`; `POST/PUT/DELETE /products` |
| `StoreService` | `GET /stores`, `/stores/{id}`; `POST /stores`; `PUT /stores/{id}`; `PATCH /stores/{id}/verify`; `DELETE /stores/{id}` |
| `PriceService` | `GET /prices`; `POST /prices`; `POST /prices/{id}/vote`; `DELETE /prices/{id}` |
| `ReportService` | `GET /reports`; `POST /reports`; `DELETE /reports/{id}` |
| `CatalogService` | official prices (+ history), units, brands, locations, sectors, `GET /admin/dashboard-stats`, `GET /admin/recent-activity` |
| `AdminUserService` | `GET/POST /admin/users`, `PUT/DELETE /admin/users/{id}`, `PATCH .../block`, `.../unblock`, `.../role` |

## 3. Mock-only paths

Every `MockData` reference in the app was already behind
`if (AppConfig.useMockData)` inside `app_provider.dart` — 15 call sites, no
screen touched `MockData` directly. Flipping the switch was therefore enough to
take the whole app off mock data, **except** for hardcoded values baked into
widgets (see §6).

## 4. Contract contradictions found

| # | Contradiction | Resolution |
|---|---|---|
| 1 | `API_DOCUMENTATION.md` said `POST /auth/register` returns `access_token` + `refresh_token`; the OTP screen implied the account is not usable until verified | Register issues **no tokens**. Tokens are issued by `POST /auth/verify-otp`. |
| 2 | The Dio refresh interceptor read `response.data['access_token']` while every other endpoint used the `{success, data}` envelope | Refresh returns the envelope; the interceptor now reads `data.access_token`. |
| 3 | `PriceEntry.status` (`pending`/`approved`/`rejected`) had no column anywhere in the ERD | No status column. Administrative review = deleting a wrong price. |
| 4 | Docs used `area` for a district; the ERD column is `district` | `district` is canonical on the wire; `area` stays as a display alias. |
| 5 | `UserModel` had no `location_id`, yet `users.location_id` is a real FK | Added `locationId`; `/auth/me` returns it. |
| 6 | `StoreModel` dropped `location_id` on parse, so a store could not be edited or filtered by id | Added `locationId` and `sectorId`. |
| 7 | Report types were four English keys (`wrong_price`, …); the DB CHECK allows three Arabic strings | The three Arabic strings are the only allowed values (this was already fixed in the Flutter model). |
| 8 | Role was parsed into text `'admin'`, collapsing 1 and 2 | `roleLevel` (0/1/2) is the source of truth; the backend enforces the boundary regardless. |
| 9 | Product list had no location parameter, although the whole product is location-sensitive | `GET /products?location_id=` added and wired through the app. |
| 10 | Products screen filtered on categories (`'حبوب'`, `'سكريات'`) that do not exist in `products.category` (`'حبوب ومطاحن'`, `'سكريات ومؤن'`) | Categories now come from `GET /products/categories`. |

## 5. Screens that could not work against the old contract

* **OTP verification** — could not obtain a session, because registration was
  assumed to have issued one already.
* **Home / products** — showed market prices that ignored the selected
  location entirely.
* **Add price** — needed `unit_id`/`brand_id`; the UI had them, the contract
  did not describe where they came from.
* **Store suggestion** — `location_id` is mandatory in the schema but the old
  contract sent free-text `area`/`sector`.
* **Official price history** — `GET /official-prices/{id}/history` was consumed
  by a finished screen but documented nowhere.
* **Admin price review** — filtered on a `status` field that does not exist.

## 6. Fake data baked into widgets (not behind the mock switch)

| Location | Problem | Fix |
|---|---|---|
| `home_screen.dart` header | Three stat chips hardcoded to `'16'`, `'8'`, `'24'` | Computed from the loaded products for the selected location |
| `products_screen.dart` | `_cats` hardcoded category list that matches nothing in the database | `GET /products/categories` |

These were the only places where turning off mock mode would still have shown
invented business data. Full list in `MOCK_REMOVAL_REPORT.md`.

## 7. Changes made

**Backend (new)** — Laravel 12 + PostgreSQL 16, `/api/v1`, Sanctum access
tokens plus a custom rotating refresh-token table, OTP with hashed codes,
`PriceAggregationService` (median + MAD), role middleware, 68 routes,
90 feature/unit tests against PostgreSQL.

**Flutter (modified, not redesigned)**

* `useMockData` became `bool.fromEnvironment(..., defaultValue: false)`
* refresh interceptor reads the real envelope
* `register()` no longer stores tokens; `verifyOtp()` does
* `UserModel.locationId`, `StoreModel.locationId`/`sectorId`,
  `ProductModel.unitId`/`amount`
* `selected_location_id` persisted in `SharedPreferences` and sent as
  `location_id`; changing it syncs the account location through
  `PUT /auth/profile`
* admin access decided by the server-provided `roleLevel`
* settings password change moved onto the OTP endpoints
* home stats and product categories now come from real data
* `AndroidManifest`: `INTERNET` permission and a development-only cleartext
  network-security config

No layout, colour, navigation pattern or RTL behaviour was changed.
