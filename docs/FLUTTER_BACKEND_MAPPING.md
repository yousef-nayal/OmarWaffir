# Flutter to Backend Mapping

This mapping reflects actual current code paths. Mock mode may bypass the service and use `MockData`; an API failure is not automatically converted to mock data.

## Authentication

| Screen                 | Provider                                  | Service                                           | Endpoint                                | Request                                                              | Response/model                       |
| ---------------------- | ----------------------------------------- | ------------------------------------------------- | --------------------------------------- | -------------------------------------------------------------------- | ------------------------------------ |
| SplashScreen           | AppProvider.restoreSession                | AuthService.getCurrentUser                        | GET `/auth/me`                          | none                                                                 | UserModel                            |
| LoginScreen            | AppProvider.login                         | AuthService.login                                 | POST `/auth/login`                      | phone_number, password                                               | AuthResult -> UserModel              |
| RegisterScreen         | CatalogProvider then AppProvider.register | CatalogService.getLocations; AuthService.register | GET `/locations`; POST `/auth/register` | search; then name, phone_number, password, confirmation, location_id | LocationModel list; AuthResult       |
| OtpVerificationScreen  | AppProvider.verifyOtp                     | AuthService.verifyOtp                             | POST `/auth/verify-otp`                 | phone_number, code                                                   | ignored                              |
| OtpVerificationScreen  | AppProvider.resendOtp                     | AuthService.resendOtp                             | POST `/auth/resend-otp`                 | phone_number                                                         | ignored                              |
| AdminLoginScreen       | AppProvider.adminLogin                    | AuthService.adminLogin                            | POST `/auth/admin/login`                | username, password                                                   | AuthResult -> UserModel              |
| ForgotPasswordScreen   | AppProvider.forgotPassword                | AuthService.forgotPassword                        | POST `/auth/forgot-password`            | phone_number                                                         | ignored                              |
| ResetPasswordScreen    | AppProvider.resetPassword                 | AuthService.resetPassword                         | PUT `/auth/reset-password`              | phone_number, code, new_password, confirmation                       | ignored                              |
| Profile/settings       | AppProvider.updateProfile                 | AuthService.updateProfile                         | PUT `/auth/profile`                     | name                                                                 | UserModel                            |
| Settings               | AppProvider.changePassword                | AuthService.changePassword                        | PUT `/auth/change-password`             | current_password, new_password, confirmation                         | ignored                              |
| Logout action          | AppProvider.logout                        | AuthService.logout                                | POST `/auth/logout`                     | none                                                                 | ignored                              |
| Any Dio call after 401 | interceptor                               | internal Dio POST                                 | POST `/auth/refresh`                    | refresh_token                                                        | access_token, optional refresh_token |

## User product and store flows

| Screen                       | Provider                        | Service                       | Endpoint                         | Request/query                                          | Response/model                  |
| ---------------------------- | ------------------------------- | ----------------------------- | -------------------------------- | ------------------------------------------------------ | ------------------------------- |
| HomeScreen/ProductsScreen    | ProductProvider                 | ProductService                | GET `/products`                  | search, category, page, per_page                       | ApiResponse<List<ProductModel>> |
| Product detail               | PriceProvider                   | ProductService                | GET `/products/{id}/prices`      | product id                                             | List<PriceEntry>                |
| Product detail               | PriceProvider                   | PriceService                  | POST `/prices/{id}/vote`         | is_up                                                  | ignored                         |
| Product detail report dialog | ReportProvider                  | ReportService                 | POST `/reports`                  | price_id, type, conditional description                | ReportModel                     |
| AddPriceScreen               | PriceProvider                   | PriceService                  | POST `/prices`                   | product_id, store_id, price, unit_id, amount, brand_id | PriceEntry                      |
| StoresScreen                 | StoreProvider                   | StoreService                  | GET `/stores`                    | search, sector, page, per_page                         | ApiResponse<List<StoreModel>>   |
| AddStoreScreen               | CatalogProvider + StoreProvider | CatalogService + StoreService | GET `/locations`; POST `/stores` | search; location_id, name, address                     | LocationModel list; StoreModel  |

## Admin product/store/price/report flows

| Screen             | Provider        | Service        | Endpoint                    | Request/query                       | Response/model |
| ------------------ | --------------- | -------------- | --------------------------- | ----------------------------------- | -------------- |
| Admin products     | ProductProvider | ProductService | POST `/products`            | name, category                      | ProductModel   |
| Admin products     | ProductProvider | ProductService | PUT `/products/{id}`        | name, category                      | ProductModel   |
| Admin products     | ProductProvider | ProductService | DELETE `/products/{id}`     | id                                  | ignored        |
| Admin stores       | StoreProvider   | StoreService   | GET `/stores`               | search, sector, page, per_page      | Store list     |
| Admin stores       | StoreProvider   | StoreService   | PUT `/stores/{id}`          | name, address, optional location_id | StoreModel     |
| Admin stores       | StoreProvider   | StoreService   | PATCH `/stores/{id}/verify` | is_verified                         | ignored        |
| Admin stores       | StoreProvider   | StoreService   | DELETE `/stores/{id}`       | id                                  | ignored        |
| Admin price review | PriceProvider   | PriceService   | GET `/prices`               | page, per_page                      | Price list     |
| Admin price review | PriceProvider   | PriceService   | DELETE `/prices/{id}`       | id                                  | ignored        |
| Admin reports      | ReportProvider  | ReportService  | GET `/reports`              | page, per_page                      | Report list    |
| Admin reports      | ReportProvider  | ReportService  | DELETE `/reports/{id}`      | id                                  | ignored        |

## Catalog and dashboard flows

| Screen                    | Provider                      | Service          | Endpoint family                        | Models                    |
| ------------------------- | ----------------------------- | ---------------- | -------------------------------------- | ------------------------- | ---------------------- |
| Official prices           | CatalogProvider               | CatalogService   | GET/POST/PUT/DELETE `/official-prices` | OfficialPrice             |
| Official history          | CatalogProvider               | CatalogService   | GET `/official-prices/{id}/history`    | OfficialPriceHistoryEntry |
| Units                     | CatalogProvider               | CatalogService   | GET/POST/PUT/DELETE `/units`           | UnitModel                 |
| Brands                    | CatalogProvider               | CatalogService   | GET/POST/PUT/DELETE `/brands`          | BrandModel                |
| Locations                 | CatalogProvider               | CatalogService   | GET/POST/PUT/DELETE `/locations`       | LocationModel             |
| Sectors                   | CatalogProvider               | CatalogService   | GET/POST/PUT/DELETE `/sectors`         | SectorModel               |
| Admin users/admins        | AdminUsersProvider            | AdminUserService | GET `/admin/users`                     | UserModel list            |
| Admin users/admins        | AdminUsersProvider            | AdminUserService | PATCH block/unblock                    | none                      | local UserModel update |
| Admin users/admins        | AdminUsersProvider            | AdminUserService | PATCH `/admin/users/{id}/role`         | numeric role              | local UserModel update |
| Admin users/admins        | AdminUserService via provider | AdminUserService | POST/PUT/DELETE `/admin/users`         | user fields               | UserModel/ignored      |
| Admin dashboard/analytics | CatalogProvider               | CatalogService   | GET `/admin/dashboard-stats`           | none                      | untyped map            |
| Admin/home activity       | CatalogProvider               | CatalogService   | GET `/admin/recent-activity`           | none                      | untyped map list       |

## Models used by UI

`UserModel`, `ProductModel`, `StoreModel`, `PriceEntry`, `ReportModel`, `OfficialPrice`, `OfficialPriceHistoryEntry`, `UnitModel`, `BrandModel`, `LocationModel`, and `SectorModel` are defined in `lib/models/models.dart`. Dashboard statistics and recent activity remain `Map<String, dynamic>` in the current client.

## Local-only behavior

- `AleppoBlocks` persistence and dark mode use local storage; they are not backend APIs.
- MockData mutations are local only.
- No upload screen or upload service call exists.
- Navigation to admin routes is registered in `main.dart`; backend authorization is still required.
