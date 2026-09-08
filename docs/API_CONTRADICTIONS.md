> **RESOLVED — superseded by [`FINAL_API_CONTRACT.md`](FINAL_API_CONTRACT.md).**
>
> Every contradiction listed below was decided and implemented. The resolutions
> are summarised in [`IMPLEMENTATION_AUDIT.md`](IMPLEMENTATION_AUDIT.md) section 4
> and are covered by the backend test suite. This file is kept only as a record
> of what the disagreements were; do not build against it.

# API Contradictions

Each item compares the current Flutter implementation with `API_DOCUMENTATION.md` and model/provider behavior.

|   # | Area                    | Flutter behavior                                                                    | Documentation behavior                                          | Impact                                                  | Classification / action                                                    |
| --: | ----------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------------- |
|   1 | Refresh response        | Interceptor reads root `access_token` and `refresh_token`                           | General envelope places values under `data`                     | Refresh may fail on documented response                 | CONFIRMED; choose final response shape                                     |
|   2 | Registration OTP        | `AuthService.register` saves tokens immediately                                     | Flow says OTP verification is required before activation        | Restart can restore a pre-OTP session                   | CONFIRMED code risk; lifecycle NEEDS_CONFIRMATION                          |
|   3 | Normal login role       | `AppProvider.login` forces `isAdmin: false`                                         | API returns numeric role                                        | Admin returned from normal login is routed as user      | CONFIRMED; backend role semantics and client fix need decision             |
|   4 | Admin login role        | Provider forces admin based on screen, without validating response role             | API returns role 1 or 2                                         | UI assumption is not server authorization               | CONFIRMED; server must enforce                                             |
|   5 | Admin route guard       | Routes are registered without route-level role guard                                | Admin endpoints are described as administrative                 | Direct navigation is not a security boundary            | CONFIRMED; backend authorization required                                  |
|   6 | Price status            | `PriceEntry.status` and mock filtering exist; service accepts `status` but omits it | Docs state no Price status                                      | Mock and remote semantics differ                        | CONFIRMED; decide whether status exists; current API should not require it |
|   7 | Admin user status       | Service sends optional `status` query                                               | Docs omit status and note block storage is unresolved           | Filter contract is incomplete                           | CONFIRMED; NEEDS_CONFIRMATION                                              |
|   8 | Catalog updates         | PUT unit/brand endpoints are implemented                                            | Docs list GET/POST/DELETE only                                  | Backend route coverage differs                          | CONFIRMED; document or remove after decision                               |
|   9 | Catalog deletes/updates | official price, location, price, admin-user CRUD routes exist in code               | Several are absent from docs                                    | Backend developer cannot rely on docs alone             | CONFIRMED; use endpoint matrix as current code inventory                   |
|  10 | Location naming         | Model uses `area`, fallback `district`, and emits `area`/`landmark` in `toJson`     | Canonical write key is `district`; no landmark on create/update | Generic model serialization could send wrong fields     | CONFIRMED; canonical backend key NEEDS_CONFIRMATION                        |
|  11 | Store location          | Store writes `location_id`; StoreModel does not read/store it                       | Store response example contains `location_id`                   | Client cannot preserve location ID from response        | CONFIRMED contract gap                                                     |
|  12 | Location resolution     | Provider matches area name only                                                     | Relationship is `location_id` and `sector_id`                   | Duplicate area names can resolve incorrectly            | CONFIRMED risk; backend should return stable IDs                           |
|  13 | Role serialization      | `UserModel.toJson` emits textual `role`; admin service sends numeric role           | API admin role body expects numeric values                      | Generic User serialization is unsafe                    | CONFIRMED; numeric API role is canonical                                   |
|  14 | Role levels             | Parser preserves 0/1/2 but `roleToInt` can send only 0/1                            | Docs mention role 0/1/2                                         | Cannot write role 2 through current helper              | CONFIRMED; meaning of 2 NEEDS_CONFIRMATION                                 |
|  15 | Report default          | Missing report type defaults to `other`                                             | Docs allow only three Arabic values                             | Malformed response can contain invalid enum             | CONFIRMED; backend must always return valid type                           |
|  16 | Report payload name     | Service parameter is called `note`, network key is `description`                    | Docs use `description`                                          | Internal name differs only; wire contract agrees        | CONFIRMED no backend change                                                |
|  17 | Auth recovery methods   | verify/resend/reset are used                                                        | Supplied docs do not define all of them                         | Missing request/response contract                       | CONFIRMED; backend decisions required                                      |
|  18 | Pagination consumption  | Services parse metadata, some providers discard it                                  | Docs define pagination for lists                                | Backend can return it, but some UI cannot use it yet    | CONFIRMED implementation limitation                                        |
|  19 | Date parsing            | Several models use throwing `DateTime.parse`                                        | Docs show ISO-like timestamps but no guarantee                  | Malformed/null dates can crash parsing                  | CONFIRMED; timestamp guarantee NEEDS_CONFIRMATION                          |
|  20 | Numeric parsing         | Money accepts numeric strings; counters use `as int`                                | Docs show mixed numeric examples                                | Counter strings can fail                                | CONFIRMED; choose JSON numeric policy                                      |
|  21 | Uploads                 | Generic `ApiClient.upload` exists                                                   | Docs mention possible receipt upload but no endpoint            | No concrete Laravel upload contract                     | CONFIRMED; NEEDS_CONFIRMATION                                              |
|  22 | Detail endpoints        | Product/store detail services exist but no current calls found                      | Docs list both endpoints                                        | Routes may be required later, not active UI dependency  | CONFIRMED coverage distinction                                             |
|  23 | Configuration           | API URL is dart-define; mock flag is hard-coded true                                | Docs instruct changing source flag                              | Production environment switch is not fully externalized | CONFIRMED; future config decision                                          |

## Recommended resolution order

1. Fix and freeze the response envelope, especially refresh.
2. Decide OTP token issuance and session restoration policy.
3. Define numeric role meanings and role-write API.
4. Decide whether Price status exists.
5. Canonicalize `district` and require stable `location_id` in Store responses.
6. Publish missing CRUD and recovery endpoint contracts.
7. Define timestamp, numeric, pagination, and upload guarantees.
