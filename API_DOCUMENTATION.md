# توثيق API — تطبيق وفّر (Waffir)

هذا المستند هو المرجع الوحيد الذي يحتاجه مطوّر الـ backend لبناء الـ API الذي
يتصل به تطبيق وفّر. كل شكل JSON هنا مطابق تماماً لِـ `fromJson`/`toJson` في
`lib/models/models.dart`، وكل مسار (endpoint) مطابق لما يستدعيه كل Service في
`lib/core/network/services/` و `lib/features/auth/data/auth_service.dart`.

## 0. كيف يعمل التطبيق الآن ولماذا

التطبيق حالياً يعمل بالكامل على **بيانات وهمية (Mock Data)** لأغراض العرض
والتصميم. مفتاح التبديل موجود في ملف واحد:

```
lib/core/config/app_config.dart
  static const bool useMockData = true;   // غيّرها إلى false عند التسليم
```

كل شاشة في التطبيق مبنية بالفعل فوق طبقة الـ API (ApiClient + Services +
Providers)، لذا لا حاجة لتعديل أي واجهة عند ربط الـ backend — فقط:

1. ابنِ الـ endpoints أدناه بنفس الشكل تماماً.
2. غيّر `useMockData` إلى `false`.
3. شغّل التطبيق مع:
   ```
   flutter run --dart-define=API_BASE_URL=https://your-domain.com/v1
   ```

## 1. القواعد العامة

- **Base URL**: يُمرَّر عبر `--dart-define=API_BASE_URL=...` (افتراضياً
  `https://api.waffir.sy/v1`).
- **الترميز**: كل الطلبات والردود JSON، `Content-Type: application/json`.
- **اللغة**: يرسل التطبيق `Accept-Language: ar` — رسائل الأخطاء يجب أن تكون
  بالعربية لتظهر مباشرة للمستخدم.
- **المصادقة**: JWT عبر `Authorization: Bearer <access_token>` على كل الطلبات
  المحمية (كل شيء عدا auth/login, auth/register, auth/admin/login,
  auth/forgot-password).
- **شكل الرد الموحّد** (أي endpoint يُرجع قائمة أو عنصر واحد يتبع هذا الشكل):

```json
{
  "success": true,
  "data": {
    /* أو [ ] لقائمة */
  },
  "message": "نص اختياري",
  "pagination": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 20,
    "total": 93
  }
}
```

`pagination` يظهر فقط في الـ endpoints التي تُرجع قوائم قابلة للترقيم.

- **أخطاء**: أي كود حالة غير 2xx يجب أن يُرجع:

```json
{
  "success": false,
  "message": "رسالة الخطأ بالعربية",
  "errors": { "field": ["..."] }
}
```

أكواد الحالة التي يتعرف عليها التطبيق: `401` (منتهي الجلسة)، `403` (ممنوع)،
`404` (غير موجود)، `422` (خطأ تحقق/validation، مع `errors`)، `500+` (خطأ خادم).

---

## 2. المصادقة (Auth)

### POST /auth/login

طلب:

```json
{ "phone_number": "0944123456", "password": "••••••" }
```

رد (`data`):

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "user": {
    "id": "1",
    "name": "محمد أحمد",
    "phone_number": "0944123456",
    "role": 0,
    "location": "حلب - الفرقان",
    "prices_count": 45,
    "ratings_count": 56,
    "reports_count": 3,
    "is_active": true
  }
}
```

### POST /auth/register

طلب:

```json
{
  "name": "محمد أحمد",
  "phone_number": "0944123456",
  "password": "••••••",
  "password_confirmation": "••••••",
  "location_id": "12"
}
```

رد: نفس شكل `/auth/login`.

### POST /auth/admin/login

طلب: `{ "username": "admin@waffir.sy", "password": "••••••" }` (يقبل هاتف أو بريد)
رد: نفس شكل `/auth/login` مع `role: 1` أو `role: 2`.

### POST /auth/logout

بدون body، يُبطل الـ refresh token في الخادم.

### GET /auth/me

يُستخدم عند فتح التطبيق لاستعادة الجلسة تلقائياً (auto-login) إن وُجد توكن محفوظ.
رد: نفس شكل `user` أعلاه.

### PUT /auth/profile

طلب: `{ "name": "الاسم الجديد" }` → رد: كائن `user` محدّث.

### POST /auth/refresh

طلب: `{ "refresh_token": "..." }` → رد: `{ "access_token": "...", "refresh_token": "..." }`
(يُستدعى تلقائياً من `ApiClient` عند انتهاء صلاحية التوكن، عبر Interceptor.)

### POST /auth/forgot-password

طلب: `{ "phone_number": "0944123456" }` → يرسل رمز/رابط استعادة عبر SMS.

### PUT /auth/change-password

طلب: `{ "current_password": "...", "new_password": "...", "new_password_confirmation": "..." }`

---

## 3. المنتجات (Products)

نموذج `ProductModel`:

```json
{
  "id": "1",
  "name": "رز أبيض",
  "category": "حبوب",
  "official_price": 12000,
  "real_price": 15500,
  "avg_price": 15200,
  "unit": "كغ",
  "prices_count": 4,
  "change_percent": 29,
  "is_price_up": true
}
```

- **GET /products?search=&category=&page=&per_page=** → قائمة `ProductModel` (paginated)
- **GET /products/{id}** → `ProductModel` واحد
- **GET /products/{id}/prices** → قائمة `PriceEntry` الخاصة بهذا المنتج
- **POST /products** _(إداري)_ → `{ "name": "...", "category": "..." }`
- **PUT /products/{id}** _(إداري)_ → `{ "name": "...", "category": "..." }`
- **DELETE /products/{id}** _(إداري)_

`change_percent` و `is_price_up` يُفضَّل حسابهما في الخادم بمقارنة `real_price`
مع `official_price` بدل حسابهما في التطبيق.

---

## 4. المتاجر (Stores)

نموذج `StoreModel`:

```json
{
  "id": "1",
  "name": "محل الأمانة",
  "address": "شارع الفرقان الرئيسي",
  "location_id": "12",
  "is_verified": true,
  "prices_count": 24
}
```

- **GET /stores?search=&sector=&page=&per_page=**
- **GET /stores/{id}**
- **POST /stores** → `{ "location_id", "name", "address" }` (يمكن استخدامه من مستخدم عادي كـ"اقتراح متجر جديد" بحالة `pending` حتى يوثّقه الإداري)
- **PUT /stores/{id}** _(إداري)_ → `{ "name", "address", "location_id"? }`
- **PATCH /stores/{id}/verify** _(إداري)_ → `{ "is_verified": true }`
- **DELETE /stores/{id}** _(إداري)_

---

## 5. الأسعار المُقدَّمة من المستخدمين (Prices)

نموذج `PriceEntry`:

```json
{
  "id": "1",
  "product_name": "زيت زيتون فلسطين",
  "store_name": "سوبر ماركت النور",
  "store_area": "الميدان",
  "price": 45000,
  "unit_id": "1",
  "amount": 1,
  "brand_id": "2",
  "submitted_by": "محمد أحمد",
  "submitted_at": "2026-05-17T10:00:00Z",
  "thumbs_up": 12,
  "thumbs_down": 2,
  "total_ratings": 14
}
```

- **GET /prices?page=&per_page=** _(مراجعة إدارية؛ لا يوجد status في جدول Price)_
- **POST /prices** → إرسال سعر من المستخدم (شاشة "إضافة سعر"):
  ```json
  {
    "product_id": "1",
    "store_id": "2",
    "price": 15500,
    "unit_id": "1",
    "amount": 1,
    "brand_id": "2"
  }
  ```
- **POST /prices/{id}/vote** → `{ "is_up": true }` (إعجاب/عدم إعجاب من مستخدم آخر)
- **DELETE /prices/{id}** _(إداري)_

---

## 6. البلاغات (Reports)

نموذج `ReportModel`:

```json
{
  "id": "1",
  "product_name": "زيت زيتون فلسطين",
  "store_name": "سوبر ماركت النور",
  "store_area": "العزيزية",
  "user_name": "أحمد محمود",
  "type": "سعر غير صحيح",
  "description": null,
  "reported_at": "2026-05-17T14:30:00Z"
}
```

`type` من: `سعر مبالغ فيه` | `سعر غير صحيح` | `معلومات غير صحيحة`.
يُسمح بالحقل `description` فقط عندما تكون قيمة `type` هي `معلومات غير صحيحة`.

- **GET /reports?page=&per_page=** _(إداري)_
- **POST /reports** → `{ "price_id": "1", "type": "سعر غير صحيح" }`
- **DELETE /reports/{id}** _(إداري)_

---

## 7. إدارة المستخدمين (Admin Users)

- **GET /admin/users?search=&page=&per_page=** → قائمة `UserModel`
- **PATCH /admin/users/{id}/block** أو **/admin/users/{id}/unblock**
- **PATCH /admin/users/{id}/role** → `{ "role": 0 }` أو `{ "role": 1 }` أو `{ "role": 2 }`

ملاحظة مهمة: مخطط SQL الحالي لا يحتوي عمود `is_active` أو `status` في جدول
`User`. لذلك يجب على الخادم تنفيذ الحظر في جدول مستقل (مثلاً UserBlock) أو
إضافة عمود مخصص قبل تفعيل مساري الحظر وفلتر `status`. لا يجوز ادعاء أن هذه
الحالة محفوظة داخل جدول `User` الحالي.

---

## 8. بيانات مرجعية إدارية بسيطة

### الأسعار الرسمية (`OfficialPrice`)

```json
{
  "id": "1",
  "product_id": "1",
  "unit_id": "2",
  "product_name": "زيت زيتون فلسطين",
  "unit": "لتر",
  "amount": 1,
  "price": 43000,
  "created_at": "2026-05-15T00:00:00Z"
}
```

- **GET /official-prices?search=**
- **POST /official-prices** → `{ "product_id", "unit_id", "amount", "price" }`
- **PUT /official-prices/{id}** → `{ "product_id", "unit_id", "amount", "price" }`
- **DELETE /official-prices/{id}**
- **GET /official-prices/{id}/history** → سجل الصفوف السابقة للسعر. بما أن
  المخطط الحالي لا يحتوي `updated_at` ولا جدول تاريخ منفصلاً، يجب تنفيذ
  تعديل السعر كسجل جديد (INSERT) والحفاظ على السجلات السابقة، أو إضافة جدول
  تاريخ مستقل قبل تفعيل هذا المسار.

### الوحدات (`UnitModel`)

```json
{ "id": "1", "name": "كيلوغرام", "usage_count": 456 }
```

- **GET /units** — **POST /units** `{ "name" }` — **DELETE /units/{id}**

### العلامات التجارية (`BrandModel`)

```json
{ "id": "1", "name": "فلسطين", "products_count": 45 }
```

- **GET /brands** — **POST /brands** `{ "name" }` — **DELETE /brands/{id}**

### المواقع والقطاعات (`LocationModel`)

```json
{
  "id": "1",
  "sector_id": "5",
  "sector": "الكتلة الخامسة",
  "district": "الميدان",
  "stores_count": 45
}
```

- **GET /sectors** → قائمة `{ "id", "name", "description" }`
- **POST /sectors** _(إداري)_ → `{ "name", "description" }`
- **PUT /sectors/{id}** _(إداري)_ → `{ "name", "description" }`
- **DELETE /sectors/{id}** _(إداري)_
- **GET /locations?search=**
- **POST /locations** → `{ "sector_id", "district" }`
- **PUT /locations/{id}** → `{ "sector_id", "district" }`
- **DELETE /locations/{id}**

`sector_id` هو مفتاح أجنبي إلى `Sector.id`، و`district` يطابق عمود
`Location.district`. لا يرسل التطبيق `landmark` أو اسم القطاع كنص عند إنشاء
أو تعديل الموقع. استجابات المواقع يمكنها تضمين `sector` كاسم جاهز للعرض، لكن
مصدر الحقيقة هو `sector_id`.

---

## 9. لوحة الإحصائيات الإدارية

### GET /admin/dashboard-stats

```json
{
  "totalUsers": 1248,
  "totalProducts": 856,
  "totalStores": 324,
  "totalPrices": 4562,
  "totalReports": 89,
  "usersGrowth": 12,
  "productsGrowth": 8,
  "storesGrowth": 5,
  "pricesGrowth": 18
}
```

### GET /admin/recent-activity

```json
[
  {
    "type": "price",
    "text": "تم إضافة سعر جديد لمنتج زيت زيتون فلسطين",
    "time": "منذ 5 دقائق",
    "color": "blue"
  }
]
```

`type`: price | report | user | store | official. `color`: blue | red | green | purple.

---

## 10. رفع الملفات

`ApiClient.upload()` جاهز لأي endpoint يستقبل `multipart/form-data` (مثلاً صورة
إيصال عند إرسال سعر). لا يوجد endpoint فعلي مطلوب بعد — إن احتجتم صور إثبات
للأسعار، أضيفوا حقل `receipt_image` إلى `POST /prices` كـ multipart وأخبرونا
لنفعّله في التطبيق.

---

## 11. خريطة سريعة: أين يقع كل شيء في كود Flutter

| الطبقة                                    | الملف                                      |
| ----------------------------------------- | ------------------------------------------ |
| عميل HTTP + إدارة التوكن                  | `lib/core/network/api_client.dart`         |
| شكل الأخطاء الموحّد                       | `lib/core/network/api_exception.dart`      |
| شكل الرد الموحّد + Pagination             | `lib/core/network/api_response.dart`       |
| كل الـ Services (منتجات، متاجر، أسعار...) | `lib/core/network/services/*.dart`         |
| خدمة المصادقة                             | `lib/features/auth/data/auth_service.dart` |
| الحالة العامة + تبديل mock/real           | `lib/core/utils/app_provider.dart`         |
| مفتاح mock/real ورابط الـ API             | `lib/core/config/app_config.dart`          |
| كل الـ Models وتحويل JSON                 | `lib/models/models.dart`                   |

أي عدم تطابق بين هذا الملف والكود الفعلي، اعتمدوا الكود كمرجع نهائي (خصوصاً
دوال `fromJson`/`toJson` في `models.dart`) وأخبرونا لتحديث هذا الملف.
