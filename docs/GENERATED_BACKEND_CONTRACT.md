> **SUPERSEDED by [`FINAL_API_CONTRACT.md`](FINAL_API_CONTRACT.md)**, which is
> the contract the running backend and its tests implement.

# Generated Backend Contract

Status vocabulary used in this document:

- **CONFIRMED**: directly observed in Flutter code or `API_DOCUMENTATION.md`.
- **INFERRED**: derived from call paths or model behavior, but not an explicit backend guarantee.
- **RECOMMENDED**: implementation advice, not a client requirement.
- **NEEDS_CONFIRMATION**: the client cannot determine the answer.

This document describes the current Flutter client. It does not claim that a Laravel backend exists or that any endpoint is currently reachable.

## Base URL

**CONFIRMED**: `API_BASE_URL` is read with `String.fromEnvironment`.

- Default in current source: `https://api.waffir.sy/v1`.
- Runtime override: `--dart-define=API_BASE_URL=...`.
- Relative paths below are appended to this base URL.
- `APP_ENV` and `USE_MOCK_DATA` are not currently implemented in the inspected source. **NEEDS_CONFIRMATION / future configuration requirement**.

## Transport

**CONFIRMED** headers on JSON requests:

```http
Accept: application/json
Content-Type: application/json
Accept-Language: ar
Authorization: Bearer <access_token>   # added when an access token exists
```

Timeouts are 30 seconds for connect, send, and receive. Dio is a singleton central client. No service creates its own Dio instance.

## Authentication

The client stores two Secure Storage values:

- `access_token`
- `refresh_token`

Passwords are not stored by the client. The access token is sent as a Bearer token on every request when present.

A 401 response triggers the Dio interceptor, except for `/auth/refresh`. Concurrent failed requests are queued while one refresh attempt runs. On refresh failure the current client deletes secure storage and rejects queued requests. Whether the Laravel refresh token is rotated, its expiry, or its revocation model is **NEEDS_CONFIRMATION**.

The refresh parser currently expects root-level token fields, while the documented general envelope places fields under `data`. The backend must either support both during transition or confirm one final shape; this is a known contradiction documented separately.

## Response Envelope

The documented and most list-service-compatible shape is:

```json
{
  "success": true,
  "message": "optional",
  "data": {},
  "pagination": {
    "current_page": 1,
    "last_page": 10,
    "per_page": 20,
    "total": 200
  }
}
```

**CONFIRMED consumed envelope fields**: `success`, `message`, `data`, and pagination fields above.

Some client methods also accept an unwrapped object or list. This is client compatibility behavior, not a recommendation for new Laravel responses. **RECOMMENDED**: use the envelope consistently for every endpoint and return `data: null` for an action with no resource.

## Error Contract

The documented error body is:

```json
{
  "success": false,
  "message": "The given data was invalid.",
  "errors": {
    "email": ["The email field is required."]
  }
}
```

**CONFIRMED client mapping**:

| HTTP status     | Client category   | Client behavior                                                      |
| --------------- | ----------------- | -------------------------------------------------------------------- |
| 401             | unauthorized      | Session error; interceptor attempts refresh except on refresh itself |
| 403             | forbidden         | Permission error                                                     |
| 404             | notFound          | Backend message is retained when present                             |
| 422             | validation        | Backend message and `errors` map are exposed                         |
| 500+            | server            | Generic server message; backend message stored as dev message        |
| network/timeout | network/timeout   | Local connectivity/timeout message                                   |
| 400, 409, 429   | unknown currently | Final category and message policy **NEEDS_CONFIRMATION**             |

**RECOMMENDED**: keep Laravel validation values as arrays of strings and return the same envelope for 400/409/429/500 responses. The current client field is named `errors`; a separate `fieldErrors` name is not currently consumed.

## Pagination

**CONFIRMED** page-based pagination is used, not cursor pagination:

- Query keys: `page`, `per_page`.
- Default client page size: `20`.
- Response keys: `current_page`, `last_page`, `per_page`, `total`.
- Product and store providers append pages and use `current_page < last_page`.
- Price, report, and admin-user providers currently discard pagination metadata.
- No sort query is sent by the current client.

## Endpoint Contract

Unless stated otherwise, authenticated endpoints require a Bearer access token. Exact role authorization is listed only where code or documentation supports it; otherwise it is **NEEDS_CONFIRMATION**.

### Authentication

#### `POST /auth/login`

- Auth: no.
- Body: `phone_number` string, `password` string.
- Success consumed: `data.access_token`, `data.refresh_token`, `data.user`.
- Client saves both tokens.
- Expected errors: 401 and 422 are supported by client behavior; 400/429 are **NEEDS_CONFIRMATION**.

#### `POST /auth/register`

- Auth: no.
- Body: `name`, `phone_number`, `password`, `password_confirmation`, `location_id`.
- Success consumed: same `AuthResult` shape as login.
- Client currently saves both tokens before OTP verification. Whether that is valid backend policy is **NEEDS_CONFIRMATION**.

#### `POST /auth/admin/login`

- Auth: no.
- Body: `username`, `password`.
- Documentation says username may be phone or email; the current admin form is phone-oriented. Email support is **CONFIRMED by documentation, not by current screen validation**.
- Success consumed: same `AuthResult` shape.
- Required role: administrative role is **INFERRED**; server must enforce it.

#### `POST /auth/refresh`

- Auth: refresh token in body; interceptor explicitly removes Authorization for this call.
- Body: `{ "refresh_token": "string" }`.
- Current parser expects `{ "access_token": "...", "refresh_token": "..." }` at root.
- Documentation also describes an envelope response `{ "success": true, "data": { ... } }`.
- Token rotation and expiry: **NEEDS_CONFIRMATION**.

#### `POST /auth/logout`

- Auth: yes, according to documented protected routes.
- Body: none.
- Response: ignored by client.
- Client clears tokens even if request fails.
- Whether the backend invalidates the refresh token is **NEEDS_CONFIRMATION**.

#### `GET /auth/me`

- Auth: yes.
- Body/query: none.
- Success consumed: a user object, either under `data` or as a compatibility fallback.

#### `PUT /auth/profile`

- Auth: yes.
- Body: `{ "name": "string" }`.
- Success consumed: updated user under `data` or raw object.

#### `POST /auth/forgot-password`

- Auth: documented as public.
- Body: `{ "phone_number": "string" }`.
- Response: ignored.
- OTP delivery channel, expiry, and throttling: **NEEDS_CONFIRMATION**.

#### `POST /auth/verify-otp`

- Auth: no explicit Authorization requirement in client.
- Body: `{ "phone_number": "string", "code": "string" }`.
- Response: ignored.
- Whether this returns tokens or only confirms the account: **NEEDS_CONFIRMATION**.

#### `POST /auth/resend-otp`

- Auth: no explicit Authorization requirement in client.
- Body: `{ "phone_number": "string" }`.
- Response: ignored.
- Rate limit and maximum attempts: **NEEDS_CONFIRMATION**.

#### `PUT /auth/reset-password`

- Auth: no explicit Authorization requirement in client.
- Body: `phone_number`, `code`, `new_password`, `new_password_confirmation`.
- Response: ignored.
- Method and token semantics should be confirmed because this endpoint is used in code but absent from the supplied documentation.

#### `PUT /auth/change-password`

- Auth: yes.
- Body: `current_password`, `new_password`, `new_password_confirmation`.
- Response: ignored.

### Products

#### `GET /products`

- Auth: client does not require a token explicitly; public/protected status **NEEDS_CONFIRMATION**.
- Query: optional `search`, optional `category`, `page` default 1, `per_page` default 20.
- Success: envelope with `data` list of Product objects and optional pagination.
- Sorting: none sent.

#### `GET /products/{id}`

- Auth: **NEEDS_CONFIRMATION**.
- Path: `id`.
- Success: Product object under `data` or raw compatibility shape.
- Current service exists but no current screen/provider call was found.

#### `GET /products/{id}/prices`

- Auth: **NEEDS_CONFIRMATION**.
- Path: product `id`.
- Success: list of PriceEntry objects, wrapped or raw list accepted by current service.
- Pagination: not consumed.

#### `POST /products`

- Auth: admin intent is documented.
- Body: `name`, `category`.
- Success: created Product under `data` or raw compatibility shape.

#### `PUT /products/{id}`

- Auth: admin intent is documented.
- Path: `id`.
- Body: `name`, `category`.
- Success: updated Product.

#### `DELETE /products/{id}`

- Auth: admin intent is documented.
- Path: `id`.
- Body: none; response ignored.

### Stores

#### `GET /stores`

- Auth: **NEEDS_CONFIRMATION**.
- Query: optional `search`, optional `sector`, `page`, `per_page`.
- Note: current client sends sector as a query string, although IDs are used for write operations.
- Success: list of Store objects plus pagination.

#### `GET /stores/{id}`

- Auth: **NEEDS_CONFIRMATION**.
- Path: `id`.
- Success: Store object.
- Service exists; no current provider/screen call found.

#### `POST /stores`

- Auth: login is **INFERRED** for ordinary user submission; documentation says an ordinary user may suggest a store.
- Body: `location_id`, `name`, `address`.
- Success: Store object.
- Pending status behavior: **NEEDS_CONFIRMATION**.

#### `PUT /stores/{id}`

- Auth: admin intent documented.
- Path: `id`.
- Body: required `name`, `address`; optional `location_id`.
- Success: Store object.

#### `PATCH /stores/{id}/verify`

- Auth: admin intent documented.
- Path: `id`.
- Body: `{ "is_verified": true|false }`.
- Response ignored.

#### `DELETE /stores/{id}`

- Auth: admin intent documented.
- Path: `id`.
- Response ignored.

### Prices

#### `GET /prices`

- Auth: admin intent documented.
- Query: `page`, `per_page`.
- `status` is accepted by Dart method signature but is not transmitted. Real price status is contradicted by source comments and documentation.
- Success: list of PriceEntry plus pagination.

#### `POST /prices`

- Auth: authenticated user is **INFERRED** from user workflow.
- Body: `product_id`, `store_id`, `unit_id`, `amount`, `brand_id`, `price`.
- Success: created PriceEntry.
- Content type: JSON.
- No status is sent.

#### `POST /prices/{id}/vote`

- Auth: authenticated user is **INFERRED**.
- Path: price `id`.
- Body: `{ "is_up": true|false }`.
- Response ignored.
- Duplicate-vote policy: **NEEDS_CONFIRMATION**.

#### `DELETE /prices/{id}`

- Auth: admin intent documented.
- Path: `id`.
- Response ignored.

### Reports

#### `GET /reports`

- Auth: admin intent documented.
- Query: `page`, `per_page`.
- Success: list of ReportModel plus pagination.

#### `POST /reports`

- Auth: authenticated user is **INFERRED**.
- Body always contains `price_id`, `type`.
- `description` is sent only when type is `معلومات غير صحيحة` and text is non-empty.
- Allowed client values: `سعر مبالغ فيه`, `سعر غير صحيح`, `معلومات غير صحيحة`.
- Response: created ReportModel.

#### `DELETE /reports/{id}`

- Auth: admin intent documented.
- Path: `id`.
- Response ignored.

### Catalog and locations

The following catalog endpoints are used by admin screens or forms. Their exact guest/user/admin authorization is generally **NEEDS_CONFIRMATION** except where the documentation labels an operation admin-only.

| Method | Path                            | Body/query                                 | Consumed result                   |
| ------ | ------------------------------- | ------------------------------------------ | --------------------------------- |
| GET    | `/official-prices`              | optional `search`                          | list of OfficialPrice             |
| POST   | `/official-prices`              | `product_id`, `unit_id`, `amount`, `price` | OfficialPrice                     |
| PUT    | `/official-prices/{id}`         | same four fields                           | OfficialPrice                     |
| DELETE | `/official-prices/{id}`         | path `id`                                  | ignored                           |
| GET    | `/official-prices/{id}/history` | path `id`                                  | list of OfficialPriceHistoryEntry |
| GET    | `/units`                        | none                                       | list of UnitModel                 |
| POST   | `/units`                        | `name`                                     | UnitModel                         |
| PUT    | `/units/{id}`                   | `name`                                     | UnitModel                         |
| DELETE | `/units/{id}`                   | path `id`                                  | ignored                           |
| GET    | `/brands`                       | none                                       | list of BrandModel                |
| POST   | `/brands`                       | `name`                                     | BrandModel                        |
| PUT    | `/brands/{id}`                  | `name`                                     | BrandModel                        |
| DELETE | `/brands/{id}`                  | path `id`                                  | ignored                           |
| GET    | `/locations`                    | optional `search`                          | list of LocationModel             |
| POST   | `/locations`                    | `sector_id`, `district`                    | LocationModel                     |
| PUT    | `/locations/{id}`               | `sector_id`, `district`                    | LocationModel                     |
| DELETE | `/locations/{id}`               | path `id`                                  | ignored                           |
| GET    | `/sectors`                      | none                                       | list of SectorModel               |
| POST   | `/sectors`                      | `name`, `description`                      | SectorModel                       |
| PUT    | `/sectors/{id}`                 | `name`, `description`                      | SectorModel                       |
| DELETE | `/sectors/{id}`                 | path `id`                                  | ignored                           |

The update/delete catalog rows are used in code but missing from the supplied API documentation. **CONFIRMED contradiction**.

### Admin users and dashboard

| Method | Path                        | Auth/role        | Body/query                                                        | Consumed result                                  |
| ------ | --------------------------- | ---------------- | ----------------------------------------------------------------- | ------------------------------------------------ | ------- |
| GET    | `/admin/users`              | admin documented | optional `search`, optional `status`, `page`, `per_page`          | User list + pagination                           |
| PATCH  | `/admin/users/{id}/block`   | admin documented | none                                                              | ignored                                          |
| PATCH  | `/admin/users/{id}/unblock` | admin documented | none                                                              | ignored                                          |
| PATCH  | `/admin/users/{id}/role`    | admin documented | `{ "role": 0                                                      | 1 }` from current helper                         | ignored |
| POST   | `/admin/users`              | admin inferred   | `name`, `phone_number`, `password`, `location_id`, numeric `role` | User                                             |
| PUT    | `/admin/users/{id}`         | admin inferred   | `name`; optional `phone_number`, `password`, `location_id`        | User                                             |
| DELETE | `/admin/users/{id}`         | admin inferred   | path `id`                                                         | ignored                                          |
| GET    | `/admin/dashboard-stats`    | admin inferred   | none                                                              | map with eight documented counters/growth fields |
| GET    | `/admin/recent-activity`    | admin inferred   | none                                                              | list maps with `type`, `text`, `time`, `color`   |

`status` filtering is implemented in Dart but absent from the supplied API documentation. **CONFIRMED contradiction**.

## Model Data Dictionary

### UserModel

**CONFIRMED JSON keys read**: `id`, `name`, `phone_number` or fallback `phone`, `role`, `location`, `prices_count`, `ratings_count`, `reports_count`, `is_active`, optional `created_at`.

- `id`: string in Dart; source IDs are stringified. Read; used in paths. Write only appears in `toJson`, not in create payloads.
- `name`: string, read/write.
- `phone`: string, JSON read key `phone_number`/`phone`; create/update write key `phone_number`.
- `role`: UI label derived from numeric or textual input. API writes must be numeric in admin role operations. `UserModel.toJson()` still emits text, a contradiction.
- `roleLevel`: Dart-derived numeric role level; no separate JSON key is read.
- `location`: display string; no `location_id` is read by UserModel.
- `prices_count`, `ratings_count`, `reports_count`: integer counters.
- `is_active`: boolean, defaults true in parser.
- `created_at`: nullable ISO-like string parsed with `DateTime.tryParse`.

### ProductModel

Read keys: `id`, `name`, `category`, `official_price`, `real_price`, `avg_price`, `unit`, `prices_count`, `change_percent`, `is_price_up`. Money is converted to Dart double. Write serialization includes these keys, although product create/update send only `name` and `category`.

### StoreModel

Read keys: `id`, `name`, `address`, `area` or fallback `district`, `sector` string or nested object name, `is_verified`, `prices_count`. Current model has no `location_id`, despite write requests using it. This is a client/backend contract gap.

### PriceEntry

Read keys: `id`, `product_id`, `product_name`, `store_id`, `store_name`, `store_area`, `price`, `unit`, optional `unit_id`, `amount` or fallback `quantity`, optional `brand_id`, `brand`, `submitted_by`, `submitted_at`, `thumbs_up`, `thumbs_down`, `total_ratings`, `status`.

Write `toJson()` sends only `product_id`, `store_id`, `price`, `amount`, optional `unit_id`, optional `brand_id`. `status` is not sent.

### ReportModel

Read keys: `id`, `product_name`, `store_name`, `store_area`, `user_name`, `type`, nullable `description`, `reported_at`, optional `price`, `unit`, `amount` or fallback `quantity`. Report submission sends only `price_id`, `type`, and conditional `description`.

### Catalog models

- `OfficialPrice`: `id`, optional `product_id`, `product_name`, optional `unit_id`, `unit`, `amount` or fallback `quantity`, `price`, `updated_at` or fallback `created_at`.
- `OfficialPriceHistoryEntry`: `id`, `price`, `changed_at`.
- `UnitModel`: `id`, `name`, `usage_count`.
- `BrandModel`: `id`, `name`, `products_count`.
- `LocationModel`: `id`, optional `sector_id`, `sector`, `area` or `district`, `landmark`, `stores_count`.
- `SectorModel`: `id`, `name`, `description`.

### Dashboard and activity

Dashboard map keys are `totalUsers`, `totalProducts`, `totalStores`, `totalPrices`, `totalReports`, `usersGrowth`, `productsGrowth`, `storesGrowth`, `pricesGrowth`. Activity map keys are `type`, `text`, `time`, `color`. These maps are not typed models in current Flutter.

## Relationships

The following are supported by explicit foreign-key-shaped request fields or nested data:

| Parent   | Child         | Foreign key   | Cardinality          | Status                                   |
| -------- | ------------- | ------------- | -------------------- | ---------------------------------------- |
| Product  | Price         | `product_id`  | one-to-many inferred | INFERRED                                 |
| Store    | Price         | `store_id`    | one-to-many inferred | INFERRED                                 |
| Unit     | Price         | `unit_id`     | one-to-many inferred | INFERRED                                 |
| Brand    | Price         | `brand_id`    | one-to-many inferred | INFERRED; nullability needs confirmation |
| Sector   | Location      | `sector_id`   | one-to-many inferred | INFERRED                                 |
| Location | Store         | `location_id` | one-to-many inferred | INFERRED                                 |
| Location | User          | `location_id` | one-to-many inferred | INFERRED from register/admin-user writes |
| Price    | Report        | `price_id`    | one-to-many inferred | INFERRED                                 |
| Product  | OfficialPrice | `product_id`  | one-to-many inferred | INFERRED                                 |
| Unit     | OfficialPrice | `unit_id`     | one-to-many inferred | INFERRED                                 |

User ownership of Price/Report is displayed (`submitted_by`, `user_name`) but no explicit `user_id` request/response field is consumed. **NEEDS_CONFIRMATION**.

## Enums and states

- Role API values observed: `0`, `1`, `2`; meanings beyond `0=user`, `1/2=admin` are **INFERRED / NEEDS_CONFIRMATION**.
- Report type values are exactly the three Arabic strings listed above.
- `is_verified`, `is_active`, `is_price_up`, `is_up` are booleans.
- Activity `type`: `price`, `report`, `user`, `store`, `official` documented.
- Activity `color`: `blue`, `red`, `green`, `purple` documented.
- Price `status` is present in model/mock behavior but contradicted for real backend use. **NEEDS_CONFIRMATION**.

## Validation observed in client

- Login phone length >= 8; password length >= 4.
- Registration name non-empty; phone length >= 8; password >= 6; confirmation equal; location selection required.
- OTP exactly six digits.
- Reset password >= 6 and confirmation equal.
- Store name/address and location selection required by form flow.
- Price requires product/store/unit/brand and numeric price/amount.
- Report type required; description required only for `معلومات غير صحيحة`.
- Empty unit, brand, and sector names are rejected locally.

These are client-side rules only. Backend limits, normalization, uniqueness, password policy, OTP expiry, and numeric ranges are **NEEDS_CONFIRMATION**.

## File uploads

`ApiClient.upload()` supports multipart requests with one `filePath`, a caller-provided `fieldName`, and arbitrary extra fields. No screen or service calls it and no concrete upload endpoint or field name exists. Therefore there is no current upload contract. **NEEDS_CONFIRMATION**.

## Dates and money

- Dates are parsed from strings with Dart `DateTime.parse` or `tryParse`; exact timezone guarantee is **NEEDS_CONFIRMATION**.
- Money fields are Dart `double`: `official_price`, `real_price`, `avg_price`, `price`, `amount`, `change_percent` where applicable.
- Numeric JSON values may be int, double, or numeric strings for `_toDouble` fields. Counters currently require JSON ints.
- **RECOMMENDED**: PostgreSQL `numeric`/Laravel decimal for monetary values, with precision and scale confirmed by backend owner. This is a recommendation, not an observed schema.

## Authorization matrix

| Surface                         | Guest                             | Authenticated user | Admin                  | Super admin              |
| ------------------------------- | --------------------------------- | ------------------ | ---------------------- | ------------------------ |
| Login/register/recovery         | confirmed                         | n/a                | n/a                    | n/a                      |
| Product/store/catalog reads     | UNKNOWN                           | UNKNOWN            | UNKNOWN                | UNKNOWN                  |
| Submit price/report/vote        | UNKNOWN                           | INFERRED           | UNKNOWN                | UNKNOWN                  |
| Product/store/price/report CRUD | denied or admin intent documented | UNKNOWN            | INFERRED               | UNKNOWN                  |
| Admin users                     | UNKNOWN                           | UNKNOWN            | CONFIRMED admin intent | role 2 semantics UNKNOWN |
| Dashboard/activity              | UNKNOWN                           | UNKNOWN            | INFERRED               | UNKNOWN                  |

The backend must enforce authorization independently of Flutter UI. UI role checks are not a security boundary.

## Confirmed business rules

1. IDs, not display names, are used in price, store, location, official-price, and admin-user write payloads.
2. Report `description` is sent only for `معلومات غير صحيحة`.
3. Refresh is attempted on 401 except for the refresh endpoint itself.
4. API failure does not automatically fall back to MockData; providers expose an error state.
5. Pagination is page-based where used.

## Laravel Backend Blueprint

This is a responsibility map, not Laravel source code. Items marked **INFERRED** or **NEEDS_CONFIRMATION** must be finalized before migrations are generated.

### Controllers / route groups

| Controller or route group | Supported client surface                                                                  | Classification    |
| ------------------------- | ----------------------------------------------------------------------------------------- | ----------------- |
| AuthController            | login, register, admin login, logout, me, profile, refresh, OTP, password recovery/change | CONFIRMED surface |
| ProductController         | product list/detail/create/update/delete and product prices                               | CONFIRMED surface |
| StoreController           | store list/detail/create/update/verify/delete                                             | CONFIRMED surface |
| PriceController           | list/create/vote/delete                                                                   | CONFIRMED surface |
| ReportController          | list/create/delete                                                                        | CONFIRMED surface |
| OfficialPriceController   | list/create/update/delete/history                                                         | CONFIRMED surface |
| UnitController            | list/create/update/delete                                                                 | CONFIRMED surface |
| BrandController           | list/create/update/delete                                                                 | CONFIRMED surface |
| LocationController        | list/create/update/delete                                                                 | CONFIRMED surface |
| SectorController          | list/create/update/delete                                                                 | CONFIRMED surface |
| AdminUserController       | list/block/unblock/role/create/update/delete                                              | CONFIRMED surface |
| DashboardController       | dashboard statistics and recent activity                                                  | CONFIRMED surface |

Whether Laravel should combine or split these controllers is **RECOMMENDED** architecture, not a Flutter requirement.

### Form Requests

The following request-validation responsibilities are directly implied by request bodies:

`LoginRequest`, `RegisterRequest`, `AdminLoginRequest`, `RefreshTokenRequest`, `ProfileRequest`, `ForgotPasswordRequest`, `VerifyOtpRequest`, `ResendOtpRequest`, `ResetPasswordRequest`, `ChangePasswordRequest`, `ProductRequest`, `StoreRequest`, `PriceRequest`, `VoteRequest`, `ReportRequest`, `OfficialPriceRequest`, `UnitRequest`, `BrandRequest`, `LocationRequest`, `SectorRequest`, `AdminUserCreateRequest`, `AdminUserUpdateRequest`, and `AdminRoleRequest`.

Exact Laravel rules, maximum lengths, normalization, numeric precision, and password policy are **NEEDS_CONFIRMATION**. `description` conditional validation and the three report type values are **CONFIRMED** client requirements.

### API Resources / serializers

The client has typed parsers for `User`, `Product`, `Store`, `PriceEntry`, `Report`, `OfficialPrice`, `OfficialPriceHistoryEntry`, `Unit`, `Brand`, `Location`, `Sector`, and `AuthResult`. Laravel resources should provide these JSON keys or the Flutter parser contract must be revised. Dashboard statistics and recent activity are currently untyped maps.

### Services

Separate domain services are **RECOMMENDED** for authentication/token lifecycle, product pricing calculations, price voting, reports, official-price history, and dashboard aggregation. The client proves the endpoints and payloads, but does not prove internal Laravel service boundaries.

### Policies / gates

Laravel must enforce authorization for every endpoint regardless of Flutter route visibility. Policies/gates are **RECOMMENDED** for Product, Store, Price, Report, Catalog resources, and admin user operations. Exact role abilities for values 0/1/2 are **NEEDS_CONFIRMATION**.

### Migrations

At minimum, the client contract requires persistent concepts for users, products, stores, locations, sectors, units, brands, prices, reports, and official prices. A separate official-price history table, refresh-token table, vote table, block table, and activity table are **INFERRED or RECOMMENDED**, not proven by Flutter. Do not generate them as mandatory schema until the open questions are answered.

## Suspected / needs confirmation

OTP activation lifecycle, exact role permissions, status of suggested stores, vote idempotency, deletion/soft deletion, cascade behavior, password policy, date timezone, rate limits, upload contract, and exact envelope guarantees.
