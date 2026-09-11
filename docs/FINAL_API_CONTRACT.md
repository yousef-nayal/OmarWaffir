# Waffir API — final contract (v1)

This document supersedes `API_DOCUMENTATION.md` and the contradiction notes in
`docs/API_CONTRADICTIONS.md`. Where they disagree with this file, **this file
wins** — it is generated from the implementation that the test suite covers.

* Base URL: `http://<host>:8000/api/v1`
* Every request and response is JSON; send `Accept: application/json`
* Language: user-facing messages are Arabic (`Accept-Language: ar`)
* Timestamps: ISO-8601 UTC with a `Z` suffix — `2026-09-08T12:30:00Z`
* Ids are returned as **strings**; request bodies accept ids as strings or numbers
* Money is a JSON number; counters are JSON integers

---

## 1. Response envelope

Success:

```json
{ "success": true, "message": "...", "data": { } }
```

Paginated success:

```json
{
  "success": true,
  "message": "تم جلب البيانات بنجاح",
  "data": [ ],
  "pagination": { "current_page": 1, "last_page": 3, "per_page": 20, "total": 42 }
}
```

Action without a resource:

```json
{ "success": true, "message": "تم الحذف بنجاح", "data": null }
```

Error:

```json
{
  "success": false,
  "message": "رسالة عربية للمستخدم",
  "errors": { "field": ["..."] }
}
```

`errors` is present only for validation failures.

### Status codes

| Code | When |
|---|---|
| 200 | OK |
| 201 | Resource created |
| 401 | No/invalid/expired token, wrong credentials, dead refresh token |
| 403 | Authenticated but not allowed; blocked account; unverified phone |
| 404 | Resource not found |
| 409 | Conflict — still referenced, already verified, last super admin |
| 422 | Validation failed, or a wrong/expired OTP |
| 429 | Rate limit or OTP resend cooldown |
| 500 | Server error (message is generic unless `APP_DEBUG`) |

---

## 2. Authentication lifecycle

```
register  ──▶  (unverified account + OTP sent, NO tokens)
                     │
                verify-otp  ──▶  access_token + refresh_token + user
                     │
                   login  ──▶  access_token + refresh_token + user
                     │
                  refresh  ──▶  new access_token + NEW refresh_token
                     │              (the presented refresh token is revoked)
                   logout  ──▶  access token deleted, refresh session revoked
```

* Access token: Laravel Sanctum bearer, **60 minutes** (`SANCTUM_TOKEN_EXPIRATION`)
* Refresh token: random, SHA-256 hashed in `refresh_tokens`, **30 days**
  (`WAFFIR_REFRESH_TOKEN_DAYS`), **rotated on every refresh**
* Send `Authorization: Bearer <access_token>`; never send it to `/auth/refresh`

### Roles

| Value | Role |
|---|---|
| `0` | user |
| `1` | admin |
| `2` | super admin |

Enforced server-side by the `role:N` middleware on every admin route. The
Flutter route a screen sits on is never treated as authorisation.

---

## 3. Endpoints

Legend — **Auth**: `–` public, `U` any signed-in user, `A` role ≥ 1, `S` role 2.

### 3.1 Health

| Method | Path | Auth |
|---|---|---|
| GET | `/health` | – |

```json
{ "success": true, "message": "Waffir API",
  "data": { "status": "ok", "database_driver": "pgsql", "database": "up",
            "database_version": "PostgreSQL 16.10 …", "time": "2026-09-08T18:06:56Z" } }
```

### 3.2 Auth

| Method | Path | Auth | Rate limit |
|---|---|---|---|
| POST | `/auth/register` | – | 10/min |
| POST | `/auth/verify-otp` | – | 15/min |
| POST | `/auth/resend-otp` | – | 6/min |
| POST | `/auth/login` | – | 10/min |
| POST | `/auth/admin/login` | – | 10/min |
| POST | `/auth/refresh` | – | 30/min |
| POST | `/auth/forgot-password` | – | 6/min |
| PUT | `/auth/reset-password` | – | 10/min |
| POST | `/auth/logout` | U | |
| GET | `/auth/me` | U | |
| PUT | `/auth/profile` | U | |
| POST | `/auth/change-password/request-otp` | U | 6/min |
| PUT | `/auth/change-password` | U | |

#### POST /auth/register

```json
{ "name": "أحمد", "phone_number": "0991112233",
  "password": "Password123!", "password_confirmation": "Password123!",
  "location_id": "18" }
```

* `name` required, 2–255
* `phone_number` required, `^[0-9+]{9,15}$`, unique among non-deleted users
* `password` required, min 6, `confirmed`
* `location_id` optional, must exist in `locations`

**201** — deliberately **no tokens**:

```json
{ "success": true, "message": "تم إرسال رمز التحقق",
  "data": { "requires_verification": true, "phone_number": "0991112233" } }
```

**422** `phone_number` → `رقم الهاتف مستخدم مسبقاً`

#### POST /auth/verify-otp

```json
{ "phone_number": "0991112233", "code": "123456" }
```

**200** — the only place a new account receives a session:

```json
{ "success": true, "message": "تم تأكيد رقم الهاتف بنجاح",
  "data": { "access_token": "…", "refresh_token": "…", "user": { } } }
```

**422** `رمز التحقق غير صحيح` / `انتهت صلاحية رمز التحقق` /
`تم تجاوز عدد المحاولات المسموح بها` · **409** already verified

#### POST /auth/login

```json
{ "phone_number": "0990000001", "password": "Password123!" }
```

**200** `{ access_token, refresh_token, user }` ·
**401** `رقم الهاتف أو كلمة المرور غير صحيحة` ·
**403** `الحساب محظور` or `يجب تأكيد رقم الهاتف أولاً`

#### POST /auth/admin/login

```json
{ "username": "admin@waffir.local", "password": "Password123!" }
```

`username` is a phone number **or** an email. **403** `هذا الحساب لا يملك صلاحية
الدخول للوحة الإدارة` when the account is role 0.

#### POST /auth/refresh

```json
{ "refresh_token": "…" }
```

**200**

```json
{ "success": true, "message": "تم تجديد الجلسة",
  "data": { "access_token": "…", "refresh_token": "…" } }
```

The presented refresh token is revoked immediately. **401** when it is unknown,
already used, revoked or expired.

#### GET /auth/me

```json
{ "success": true, "data": {
  "id": "7", "name": "مستخدم وفّر", "phone_number": "0990000001", "email": null,
  "role": 0, "location_id": "18", "location": "الكتلة الثانية - الجميلية",
  "district": "الجميلية", "sector_id": "2", "sector": "الكتلة الثانية",
  "is_active": true, "phone_verified_at": "2026-09-08T18:06:31Z",
  "created_at": "2026-09-08T18:06:31Z",
  "prices_count": 3, "ratings_count": 2, "reports_count": 1 } }
```

#### PUT /auth/profile

```json
{ "name": "اسم جديد", "location_id": "24" }
```

Both optional. Returns the updated user.

#### Password recovery and change

* `POST /auth/forgot-password` — `{ "phone_number": "…" }`, sends a
  `password_reset` OTP. **422** when the number is unknown, **429** during the
  60-second cooldown.
* `PUT /auth/reset-password` — `{ phone_number, code, new_password,
  new_password_confirmation }`. Consumes the OTP atomically and **revokes every
  existing session**.
* `POST /auth/change-password/request-otp` — authenticated, sends a
  `password_change` OTP to the account's own number.
* `PUT /auth/change-password` — `{ code, new_password,
  new_password_confirmation }`. `current_password` is still accepted instead of
  `code` for backward compatibility. Signs out every **other** device.

### 3.3 Reference data

| Method | Path | Auth |
|---|---|---|
| GET | `/sectors` | – |
| POST | `/sectors` | A |
| PUT | `/sectors/{id}` | A |
| DELETE | `/sectors/{id}` | A |
| GET | `/locations` | – |
| POST | `/locations` | A |
| PUT | `/locations/{id}` | A |
| DELETE | `/locations/{id}` | A |
| GET | `/units` | – |
| POST/PUT/DELETE | `/units[/{id}]` | A |
| GET | `/brands` | – |
| POST/PUT/DELETE | `/brands[/{id}]` | A |

The GET routes are public because registration and the store-suggestion form
need them before a session exists.

`GET /locations?search=&sector_id=`

```json
{ "id": "18", "sector_id": "2", "sector": "الكتلة الثانية",
  "district": "الجميلية", "area": "الجميلية", "landmark": "", "stores_count": 2 }
```

`district` is canonical; `area` is a UI-compatibility alias carrying the same
value.

`GET /sectors` → `{ id, name, description, locations_count }`
`GET /units` → `{ id, name, usage_count }`
`GET /brands` → `{ id, name, products_count, usage_count }`

#### Deleting reference data cascades

Deleting a unit, brand, product, store, user, area or block **deletes the
prices recorded against it** - market submissions, and official prices where
the row is referenced by one. Ratings and reports follow their price (database
cascade). Deleting an area also removes the shops recorded in it, because
`stores.location_id` is not nullable; residents keep their account and only
lose the link (`users.location_id` becomes null). Deleting a block does the
same for every area under it. All of it runs in one transaction.

These deletes no longer return **409** for being referenced.

`GET /admin/deletion-impact/{type}/{id}` (admin) reports what a delete would
take with it, so the confirmation dialog can warn first. `type` is one of
`unit`, `brand`, `product`, `store`, `user`, `location`, `sector`; an unknown
type is **422**, an unknown id **404**.

```json
{ "prices": 12, "official_prices": 2, "stores": 1, "locations": 0, "users": 3 }
```

The endpoint and the delete share one service, so the numbers shown and the
rows removed cannot drift apart.

### 3.4 Products

| Method | Path | Auth |
|---|---|---|
| GET | `/products` | – |
| GET | `/products/categories` | – |
| GET | `/products/{id}` | – |
| GET | `/products/{id}/prices` | – |
| POST | `/products` | A |
| PUT | `/products/{id}` | A |
| DELETE | `/products/{id}` | A |

`GET /products?search=&category=&location_id=&sort=&page=&per_page=`

`search` matches the product name **or** its category. `sort=gap` ranks by
`real_price - official_price` for the requested location, biggest first; rows
missing either figure sink to the end. Default order is by name.

```json
{
  "id": "2", "name": "برغل", "category": "حبوب ومطاحن",
  "official_price": 85, "real_price": 92.65, "avg_price": 93.16,
  "unit": "كيلوغرام", "unit_id": "1", "amount": 1,
  "prices_count": 7, "change_percent": 9, "is_price_up": true,
  "official_price_id": "6"
}
```

`official_price`, `real_price`, `avg_price`, `change_percent`, `is_price_up`,
`prices_count` and `unit` are **computed**, not columns. With `location_id` the
market figures only consider submissions from stores in that district. See §4.

`GET /products/{id}/prices?location_id=&per_page=` returns the price objects of
§3.6, newest first.

`DELETE` is a soft delete — historic prices are preserved.

### 3.5 Stores

| Method | Path | Auth |
|---|---|---|
| GET | `/stores` | – |
| GET | `/stores/{id}` | – |
| POST | `/stores` | U |
| PUT | `/stores/{id}` | A |
| PATCH | `/stores/{id}/verify` | A |
| DELETE | `/stores/{id}` | A |

`GET /stores?search=&sector_id=&sector=&location_id=&is_verified=&page=&per_page=`

```json
{ "id": "2", "location_id": "18", "name": "سوبر ماركت كعكة",
  "address": "شارع الجميلية", "district": "الجميلية", "area": "الجميلية",
  "sector_id": "2", "sector": "الكتلة الثانية",
  "is_verified": true, "prices_count": 12, "submitted_by_user_id": null }
```

`POST /stores` — `{ location_id, name, address }`. A store submitted by a normal
user is **always** created with `is_verified: false`, even if the body says
otherwise; only an admin may pass `is_verified: true`.

### 3.6 Prices

| Method | Path | Auth |
|---|---|---|
| GET | `/prices` | A |
| POST | `/prices` | U |
| POST | `/prices/{id}/vote` | U |
| DELETE | `/prices/{id}` | A |

`GET /prices?search=&user_id=&product_id=&store_id=&sector_id=&location_id=&brand_id=&from=&to=&page=&per_page=`

`POST /prices`

```json
{ "product_id": "2", "store_id": "3", "unit_id": "1",
  "brand_id": "2", "amount": 1, "price": 95 }
```

`user_id` is always taken from the session; a `user_id` in the body is ignored.
`amount > 0`, `price >= 0`, and every foreign key must exist (**422** otherwise).

Price object:

```json
{ "id": "108", "product_id": "18", "product_name": "مربى المشمش",
  "store_id": "3", "store_name": "سوبر ماركت القلعة", "store_area": "الفرافرة",
  "location_id": "4", "sector_id": "1", "sector": "الكتلة الأولى",
  "price": 32.5, "unit": "كيلوغرام", "unit_id": "1", "amount": 2,
  "brand": "الخير", "brand_id": "2",
  "user_id": "4", "submitted_by": "أحمد", "submitted_at": "2026-09-08T15:04:00Z",
  "thumbs_up": 4, "thumbs_down": 1, "total_ratings": 5 }
```

**There is no `status` field.** Prices have no approval lifecycle; the
administrative review action is deletion.

`POST /prices/{id}/vote` — `{ "is_up": true }`. One rating per user per price
(unique index on `(user_id, price_id)`): the same value again is idempotent, a
different value updates the existing rating. Rating your own price →
**403** `لا يمكنك تقييم سعر أضفته بنفسك`.

`DELETE /prices/{id}` cascades to that price's ratings and reports.

### 3.7 Reports

| Method | Path | Auth |
|---|---|---|
| GET | `/reports` | A |
| POST | `/reports` | U |
| DELETE | `/reports/{id}` | A |

`type` must be exactly one of:

* `سعر مبالغ فيه`
* `سعر غير صحيح`
* `معلومات غير صحيحة`

`description` is **required** for `معلومات غير صحيحة` and **ignored** (stored as
`NULL`) for the other two — mirroring the database CHECK constraints.

`GET /reports?search=&user_id=&product_id=&store_id=&sector_id=&location_id=&type=&page=&per_page=`

```json
{ "id": "15", "price_id": "108", "type": "سعر مبالغ فيه", "description": null,
  "user_id": "4", "user_name": "أحمد",
  "product_id": "18", "product_name": "مربى المشمش",
  "store_id": "3", "store_name": "سوبر ماركت القلعة", "store_area": "الفرافرة",
  "location_id": "4", "sector_id": "1",
  "price": 32.5, "unit": "كيلوغرام", "amount": 2,
  "reported_at": "2026-09-08T16:00:00Z" }
```

### 3.8 Official prices

| Method | Path | Auth |
|---|---|---|
| GET | `/official-prices` | – |
| GET | `/official-prices/{id}/history` | – |
| POST | `/official-prices` | A |
| PUT | `/official-prices/{id}` | A |
| DELETE | `/official-prices/{id}` | A |

`GET /official-prices?search=&product_id=&page=&per_page=` returns only the
**current** version of each `(product, unit, amount)` series.

```json
{ "id": "6", "product_id": "2", "product_name": "برغل", "category": "حبوب ومطاحن",
  "unit_id": "1", "unit": "كيلوغرام", "amount": 1, "price": 85,
  "created_at": "2026-08-27T09:05:00Z", "updated_at": "2026-08-27T09:05:00Z" }
```

`PUT` does **not** mutate the row: it inserts a new version. The previous value
stays visible in the history screen.

`GET /official-prices/{id}/history` — every version of the same product/unit
series, newest first:

```json
{ "id": "4", "price": 79.9, "amount": 1, "unit": "كيلوغرام",
  "changed_at": "2026-07-10T09:05:00Z", "created_at": "2026-07-10T09:05:00Z" }
```

Publishing or changing an official price creates an in-app notification for
every active, verified, role-0 user.

### 3.9 Notifications

| Method | Path | Auth |
|---|---|---|
| GET | `/notifications` | U |
| GET | `/notifications/unread-count` | U |
| PATCH | `/notifications/{id}/read` | U |
| PATCH | `/notifications/read-all` | U |

```json
{ "id": "9f1c…", "type": "official_price", "title": "برغل",
  "body": "تغيّر السعر الرسمي لـبرغل من 79.9 إلى 85 ل.س",
  "product_id": "2", "is_read": false, "read_at": null,
  "created_at": "2026-09-08T18:10:00Z" }
```

### 3.10 Admin — users

| Method | Path | Auth |
|---|---|---|
| GET | `/admin/users` | A |
| POST | `/admin/users` | A (role ≥ 1 needs S to create an admin) |
| PUT | `/admin/users/{id}` | A |
| DELETE | `/admin/users/{id}` | A |
| PATCH | `/admin/users/{id}/block` | A |
| PATCH | `/admin/users/{id}/unblock` | A |
| PATCH | `/admin/users/{id}/role` | **S** |

`GET /admin/users?search=&status=active|blocked&sector_id=&location_id=&role=&page=&per_page=`

Rules enforced by the server:

| Rule | Response |
|---|---|
| Acting on your own account | 403 `لا يمكنك تنفيذ هذه العملية على حسابك الخاص` |
| An admin acting on another admin | 403 `إدارة حسابات المسؤولين متاحة للمسؤول الرئيسي فقط` |
| An admin creating an admin/super admin | 403 same message |
| Deleting or demoting the last super admin | 409 `لا يمكن حذف آخر مسؤول رئيسي في النظام` |

Blocking a user deletes their access tokens and revokes their refresh sessions
immediately. A user created by an administrator is verified on creation.
Deleting a user is a soft delete, so their prices, ratings and reports survive.

### 3.11 Admin — dashboard

| Method | Path | Auth |
|---|---|---|
| GET | `/admin/dashboard-stats` | A |
| GET | `/admin/recent-activity` | A |

```json
{ "totalUsers": 9, "totalProducts": 20, "totalStores": 12,
  "totalPrices": 126, "totalReports": 14,
  "usersGrowth": 100, "productsGrowth": 0, "storesGrowth": 100,
  "pricesGrowth": 100, "reportsGrowth": 100, "period_days": 30 }
```

Growth = the last 30 days against the 30 days before that. When the previous
window is empty the result is `100` if the current window has rows and `0`
otherwise — never a division by zero.

```json
{ "type": "price", "text": "أضاف أحمد سعراً جديداً لـبرغل في سوبر ماركت كعكة",
  "time": "منذ ٣ ساعات", "color": "green", "created_at": "2026-09-08T15:04:00Z" }
```

`type` ∈ `price | report | user | store | official`. Rows come from
`activity_logs`, written when the corresponding event really happens.

---

## 4. Representative real price

Implemented in `app/Services/PriceAggregationService.php`, unit tested in
`tests/Unit/PriceAggregationServiceTest.php`, with a Python reference in
`backend/analytics/`.

For a product (optionally restricted to one `location_id`):

1. take price events from the last **30 days** (`WAFFIR_PRICE_FRESHNESS_DAYS`)
2. keep only stores in the requested location, when one is given
3. keep only submissions recorded in the **same unit** as the current official
   price (when there is no official price, the most common unit is used)
4. normalise every submission to one unit — `price / amount`
5. drop values ≤ 0
6. reject outliers:
   * fewer than 5 samples (`WAFFIR_PRICE_MIN_SAMPLES_FOR_FILTER`) → keep all
   * modified z-score `|0.6745 · (x − median) / MAD| > 3.5`
     (`WAFFIR_PRICE_MAD_THRESHOLD`) → reject
   * `MAD = 0` → inter-quartile range, `1.5 · IQR` fence
   * `IQR = 0` as well → mean absolute deviation with the same threshold
   * a filter that would empty the set is discarded
7. `real_price = median(kept) × official_amount`,
   `avg_price = mean(kept) × official_amount`
8. `change_percent = (real_price − official_price) / official_price × 100`,
   only when both are > 0
9. `is_price_up = real_price >= official_price`
10. no usable submissions → `real_price = 0`, `avg_price = 0`

---

## 5. Error message reference

| Message | Meaning |
|---|---|
| `رقم الهاتف مستخدم مسبقاً` | Duplicate phone on register |
| `رقم الهاتف أو كلمة المرور غير صحيحة` | Bad login |
| `بيانات الدخول غير صحيحة` | Bad admin login |
| `هذا الحساب لا يملك صلاحية الدخول للوحة الإدارة` | Role 0 on the admin login |
| `الحساب محظور، يرجى التواصل مع الإدارة` | `is_active = false` |
| `يجب تأكيد رقم الهاتف أولاً` | Login before OTP verification |
| `رمز التحقق غير صحيح` / `انتهت صلاحية رمز التحقق` | OTP problems |
| `تم تجاوز عدد المحاولات المسموح بها، اطلب رمزاً جديداً` | > 5 attempts |
| `يرجى الانتظار قليلاً قبل طلب رمز جديد` | Resend cooldown (429) |
| `انتهت جلستك. يرجى تسجيل الدخول مجدداً` | 401 |
| `لا تملك صلاحية لتنفيذ هذه العملية` | 403 |
| `العنصر المطلوب غير موجود` | 404 |
| `لا يمكن الحذف لأن العنصر مستخدم في بيانات أخرى` | 409 (no longer raised by catalogue deletes - see 3.3) |
| `لا يمكنك تقييم سعر أضفته بنفسك` | Self-vote |
| `يرجى التحقق من البيانات المدخلة` | Generic 422 |

All of them live in `app/Support/Msg.php`.
