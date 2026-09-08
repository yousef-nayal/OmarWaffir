# Mock removal report

What happened to every piece of mock or hardcoded data in the app.

**Verification command**

```bash
flutter run --dart-define=USE_MOCK_DATA=false --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

With that build, no production screen shows invented business data.

---

## 1. The switch itself

`lib/core/config/app_config.dart`

```dart
static const bool useMockData = bool.fromEnvironment(
  'USE_MOCK_DATA',
  defaultValue: false,
);
```

Before: a hardcoded `true`. Now a build-time flag that **defaults to off**, so a
plain `flutter run` or `flutter build` can never accidentally ship demo data.
`test/auth_flow_test.dart` asserts this default.

There is **no fallback to `MockData` when the API fails.** A network error
surfaces as a real error through `ApiException`, exactly as it should.

## 2. `MockData` call sites — all 15

Every one lives inside `lib/core/utils/app_provider.dart`, behind
`if (AppConfig.useMockData)`. All are **kept intentionally for offline UI work**
and are unreachable in a default build.

| Provider | Method | Real replacement |
|---|---|---|
| `ProductProvider` | `loadProducts` | `GET /products` (+ `location_id`, `category`, `search`) |
| `ProductProvider` | `loadCategories` | `GET /products/categories` |
| `StoreProvider` | `loadStores` | `GET /stores` |
| `PriceProvider` | `loadProductPrices` | `GET /products/{id}/prices` |
| `PriceProvider` | `loadAdminPrices` | `GET /prices` |
| `ReportProvider` | `loadReports` | `GET /reports` |
| `CatalogProvider` | `loadOfficialPrices` | `GET /official-prices` |
| `CatalogProvider` | `loadOfficialPriceHistory` | `GET /official-prices/{id}/history` |
| `CatalogProvider` | `loadUnits` | `GET /units` |
| `CatalogProvider` | `loadBrands` | `GET /brands` |
| `CatalogProvider` | `loadLocations` | `GET /locations` |
| `CatalogProvider` | `loadSectors` | `GET /sectors` |
| `CatalogProvider` | `loadDashboardStats` | `GET /admin/dashboard-stats` |
| `CatalogProvider` | `loadRecentActivity` | `GET /admin/recent-activity` |
| `AdminUsersProvider` | `loadUsers` | `GET /admin/users` |

`AppProvider.loginMock()` is likewise mock-only and unreachable with the switch
off.

## 3. Hardcoded data inside widgets — **replaced**

These were the real problem: they were *not* behind the mock switch, so they
would have shown fake numbers even in a production build.

| File | Was | Now |
|---|---|---|
| `lib/features/user/screens/home_screen.dart` | Header stat chips hardcoded to `'16'` reasonable prices, `'8'` high prices, `'24'` monitored products | Computed from the products actually loaded for the selected location: high = `real_price > official_price`, reasonable = the rest of the priced products, monitored = `pagination.total`. Products with no market data yet are counted in neither bucket. |
| `lib/features/user/screens/products_screen.dart` | `_cats = ['الكل', 'حبوب', 'زيوت', 'سكريات', 'بقوليات']` — values that match no row in `products.category`, so filtering always returned nothing | `GET /products/categories`, and the chosen category is now sent to the server so filtering survives pagination |

## 4. Fake delayed futures — **removed from the real path**

`Future.delayed(...)` calls that simulated latency now only run inside
`if (AppConfig.useMockData)` branches. No method returns a fake success:
`submitPrice`, `vote`, `submitReport`, `createStore`, `updateProfile` and
`changePassword` all await a real HTTP call and surface real failures.

The one deliberate exception is `PriceProvider.vote()`, which updates the
counter optimistically **and rolls the change back if the request fails** — a
UX pattern, not fake data.

## 5. Reference data kept local on purpose

`lib/core/constants/aleppo_blocks.dart` still holds the five official Aleppo
blocks and their districts, and drives the location picker.

This is **kept intentionally**, because:

* it is official published reference data, not business data;
* the picker must work before a session exists (registration);
* the seeded database contains exactly the same sector and district names, so
  `CatalogProvider.locationIdForArea()` resolves the chosen district to a real
  `locations.id` before anything is sent to the server.

Nothing is ever matched by name on the server side — the app always sends ids.

## 6. What still exists but is now real

| Screen | Source of data |
|---|---|
| Home stats, "biggest differences" | `GET /products?location_id=` |
| Official prices + history | `GET /official-prices`, `.../history` |
| Product detail price list | `GET /products/{id}/prices` |
| Stores list, store suggestion | `GET /stores`, `POST /stores` |
| Profile counters | `GET /auth/me` (`prices_count`, `ratings_count`, `reports_count`) |
| Admin dashboard | `GET /admin/dashboard-stats` — real `COUNT(*)` plus 30-day growth |
| Admin recent activity | `GET /admin/recent-activity` — real rows from `activity_logs` |
| Admin users / prices / reports / stores | the corresponding admin endpoints |

## 7. Residual mock usage

`lib/core/utils/mock_data.dart` is retained as a development aid. It is
referenced only from the mock branches listed in §2 and is dead code in a
default build.
