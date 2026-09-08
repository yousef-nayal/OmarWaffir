> **SUPERSEDED — the implemented schema is in `backend/database/migrations/`**
> and is described in [`IMPLEMENTATION_REPORT.md`](IMPLEMENTATION_REPORT.md)
> section 2. This file records the requirements that led to it.

# Database Requirements

This document separates requirements observed from the Flutter client from backend recommendations. It is not a generated migration and does not assert that every inferred relationship must be implemented unchanged.

## Required Entities

The following entity concepts are directly supported by model fields and endpoint payloads.

| Entity               | Evidence                                  | Status                                              |
| -------------------- | ----------------------------------------- | --------------------------------------------------- |
| User                 | `UserModel`, auth, admin-user endpoints   | CONFIRMED concept                                   |
| Product              | `ProductModel`, product endpoints         | CONFIRMED concept                                   |
| Store                | `StoreModel`, store endpoints             | CONFIRMED concept                                   |
| Location             | `LocationModel`, `location_id` writes     | CONFIRMED concept                                   |
| Sector               | `SectorModel`, `sector_id` writes         | CONFIRMED concept                                   |
| Unit                 | `UnitModel`, `unit_id` writes             | CONFIRMED concept                                   |
| Brand                | `BrandModel`, `brand_id` writes           | CONFIRMED concept                                   |
| Price                | `PriceEntry`, price endpoints             | CONFIRMED concept                                   |
| Report               | `ReportModel`, report endpoints           | CONFIRMED concept                                   |
| OfficialPrice        | `OfficialPrice`, official-price endpoints | CONFIRMED concept                                   |
| OfficialPriceHistory | history model and endpoint                | INFERRED concept; storage design NEEDS_CONFIRMATION |

Dashboard statistics and recent activity are response projections, not confirmed database tables.

## Required Fields Observed

Types below describe the client contract, not mandatory PostgreSQL types.

### users

| Field         | Client type             | Nullable/default observed         | Key/constraint status                          |
| ------------- | ----------------------- | --------------------------------- | ---------------------------------------------- |
| id            | stringified ID          | non-null in use                   | primary key required by API identity           |
| name          | string                  | non-null in forms                 | required for registration/profile/admin create |
| phone_number  | string                  | non-null in auth flows            | uniqueness NEEDS_CONFIRMATION                  |
| role          | numeric API value 0/1/2 | default not client-controlled     | enum/check support REQUIRED by client values   |
| location_id   | ID                      | required in register/admin create | foreign key inferred                           |
| is_active     | bool                    | parser default true               | storage mechanism NEEDS_CONFIRMATION           |
| created_at    | ISO date                | nullable in model                 | timestamp support required if returned         |
| prices_count  | integer                 | parser default 0                  | projection/counter; storage strategy UNKNOWN   |
| ratings_count | integer                 | parser default 0                  | projection/counter; storage strategy UNKNOWN   |
| reports_count | integer                 | parser default 0                  | projection/counter; storage strategy UNKNOWN   |
| password      | secret                  | never read/stored by Flutter      | backend-only hash; required for auth creation  |

Password confirmation fields are request-only and must not be persisted.

### products

`id`, `name`, `category`, `official_price`, `real_price`, `avg_price`, `unit`, `prices_count`, `change_percent`, `is_price_up` are consumed. Product create/update requests only require `name` and `category`. Whether `unit` is a foreign key or display projection is **NEEDS_CONFIRMATION**.

### stores

| Field         | Client contract                           | Status                             |
| ------------- | ----------------------------------------- | ---------------------------------- |
| id            | read/path ID                              | required                           |
| name          | read/write                                | required on create/update          |
| address       | read/write                                | required on create/update          |
| location_id   | write; not currently read into StoreModel | foreign key inferred, contract gap |
| area/district | read display fallback                     | canonical name NEEDS_CONFIRMATION  |
| sector        | read display string/nested object         | projection or relation UNKNOWN     |
| is_verified   | read/write through verify endpoint        | required boolean behavior          |
| prices_count  | read counter                              | projection/counter UNKNOWN         |

### locations and sectors

Location: `id`, `sector_id`, `sector` display value, `district` canonical documented key, legacy client alias `area`, optional `landmark`, `stores_count`.

Sector: `id`, `name`, `description`.

Create/update requests use only `sector_id` and `district`; `landmark` is not sent by current service.

### units and brands

Unit: `id`, `name`, `usage_count`.

Brand: `id`, `name`, `products_count`.

### prices

Required write keys: `product_id`, `store_id`, `unit_id`, `amount`, `brand_id`, `price`.

Read projection keys additionally include `product_name`, `store_name`, `store_area`, `unit`, `brand`, `submitted_by`, `submitted_at`, rating counters, and optional `status`.

Whether `brand_id` is nullable is not established by the current write method: **NEEDS_CONFIRMATION**. Price status is contradictory and must not be added as a required database field without backend confirmation.

### reports

Required write keys: `price_id`, `type`; conditional `description`.

Read projection keys include product/store/user display fields, optional price/unit/amount, and `reported_at`.

### official prices/history

Official price writes: `product_id`, `unit_id`, `amount`, `price`.

Read fields: `id`, product/unit display projections, `updated_at` or `created_at`.

History fields: `id`, `price`, `changed_at`. Whether history is an append-only table or versioned official-price rows is **NEEDS_CONFIRMATION**.

## Foreign Keys

| Field       | Referenced concept | Type | Nullable/required                            | Classification                |
| ----------- | ------------------ | ---- | -------------------------------------------- | ----------------------------- |
| location_id | Location           | ID   | required in register/store/admin-user create | INFERRED                      |
| sector_id   | Sector             | ID   | required in location create/update           | CONFIRMED request requirement |
| product_id  | Product            | ID   | required in price/official-price writes      | CONFIRMED request requirement |
| store_id    | Store              | ID   | required in price writes                     | CONFIRMED request requirement |
| unit_id     | Unit               | ID   | required in price/official-price writes      | CONFIRMED request requirement |
| brand_id    | Brand              | ID   | required in current price service            | CONFIRMED request requirement |
| price_id    | Price              | ID   | required in report writes                    | CONFIRMED request requirement |
| user_id     | User               | ID   | not sent/consumed explicitly                 | NEEDS_CONFIRMATION            |

Table names and delete actions are not fully confirmed. Use `ASSUMED_TABLE_NAME` only if Laravel naming must be chosen before confirmation.

## Relationships

| Parent   | Child         | FK          | Cardinality          | Delete behavior    |
| -------- | ------------- | ----------- | -------------------- | ------------------ |
| Sector   | Location      | sector_id   | one-to-many inferred | NEEDS_CONFIRMATION |
| Location | User          | location_id | one-to-many inferred | NEEDS_CONFIRMATION |
| Location | Store         | location_id | one-to-many inferred | NEEDS_CONFIRMATION |
| Product  | Price         | product_id  | one-to-many inferred | NEEDS_CONFIRMATION |
| Store    | Price         | store_id    | one-to-many inferred | NEEDS_CONFIRMATION |
| Unit     | Price         | unit_id     | one-to-many inferred | NEEDS_CONFIRMATION |
| Brand    | Price         | brand_id    | one-to-many inferred | NEEDS_CONFIRMATION |
| Price    | Report        | price_id    | one-to-many inferred | NEEDS_CONFIRMATION |
| Product  | OfficialPrice | product_id  | one-to-many inferred | NEEDS_CONFIRMATION |
| Unit     | OfficialPrice | unit_id     | one-to-many inferred | NEEDS_CONFIRMATION |

## Constraints

### Required by client behavior

- IDs must be stable and usable as path parameters.
- Foreign-key-shaped IDs must resolve to existing records for successful writes.
- Role must accept numeric values `0`, `1`, `2` in responses; current admin role helper writes only `0` or `1`.
- Report type must accept exactly `سعر مبالغ فيه`, `سعر غير صحيح`, `معلومات غير صحيحة` for client compatibility.
- Report description must be allowed only for `معلومات غير صحيحة` according to documented contract.
- Price write must accept the six required keys listed above.
- Dates returned to Flutter must be parseable date strings.

### Recommended, not confirmed

- Unique normalized phone number.
- Foreign-key indexes for every `_id` field.
- Indexes for product/store/location search and paginated list filters.
- Numeric precision/scale for monetary values.
- Database check constraint for report types and role values.
- Server-side authorization policies for every admin endpoint.
- Audit/revocation storage for refresh tokens.
- Soft deletes only if product requirements require historical references; current Flutter does not establish this.

## Index recommendations

These are **RECOMMENDED**, not client-proven requirements:

- users: normalized phone, role, location_id, is_active.
- products: searchable name/category.
- stores: location_id and searchable name/address.
- locations: sector_id and district.
- prices: product_id, store_id, unit_id, brand_id, created/submitted timestamp.
- reports: price_id, type, reported timestamp.
- official prices: product_id, unit_id.
- refresh-token persistence: token hash and revocation/expiry fields if server-side rotation is used.

## Unresolved schema decisions

- Exact integer type and range for IDs.
- Canonical `district` versus client display alias `area`.
- Whether Store responses must include `location_id`.
- Whether Brand is nullable on Price.
- How counters are calculated.
- Whether status exists on Price.
- Whether official-price history is a separate table.
- Cascade/restrict behavior.
- Unique constraints beyond any existing database specification.
