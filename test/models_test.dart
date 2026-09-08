import 'package:flutter_test/flutter_test.dart';
import 'package:waffir_app/models/models.dart';

/// Parsing tests for the payloads the Laravel API actually returns.
///
/// The sample maps below are copied from real responses of the running
/// backend (see docs/FINAL_API_CONTRACT.md), so a contract change on either
/// side breaks these tests instead of the app.
void main() {
  group('UserModel', () {
    test('keeps the numeric role and the real location_id', () {
      final user = UserModel.fromJson({
        'id': 7,
        'name': 'مستخدم وفّر',
        'phone_number': '0990000001',
        'email': null,
        'role': 1,
        'location_id': '18',
        'location': 'الكتلة الثانية - الجميلية',
        'is_active': true,
        'created_at': '2026-09-08T18:06:28Z',
        'prices_count': 3,
        'ratings_count': 2,
        'reports_count': 1,
      });

      expect(user.id, '7');
      expect(user.phone, '0990000001');
      // The numeric level is what distinguishes admin (1) from super admin (2).
      expect(user.roleLevel, 1);
      expect(user.role, 'admin');
      expect(user.locationId, '18');
      expect(user.location, 'الكتلة الثانية - الجميلية');
      expect(user.pricesCount, 3);
      expect(user.ratingsCount, 2);
      expect(user.reportsCount, 1);
      expect(user.createdAt, isNotNull);
      expect(user.createdAt!.toUtc().year, 2026);
    });

    test('a normal user is role 0 and never an admin', () {
      final user = UserModel.fromJson({
        'id': '1',
        'name': 'أحمد',
        'phone_number': '0949749385',
        'role': 0,
      });

      expect(user.roleLevel, 0);
      expect(user.role, 'user');
    });

    test('a super admin keeps level 2', () {
      final user = UserModel.fromJson({'id': '1', 'name': 'x', 'role': 2});

      expect(user.roleLevel, 2);
      expect(user.roleLevelLabel, 'مسؤول رئيسي');
    });

    test('location_id survives a copyWith', () {
      final user = UserModel(id: '1', name: 'x', phone: '09', locationId: '18');

      expect(user.copyWith(name: 'y').locationId, '18');
    });

    test('a missing location_id is null, not an empty string', () {
      final user = UserModel.fromJson({'id': '1', 'name': 'x', 'role': 0});

      expect(user.locationId, isNull);
    });
  });

  group('StoreModel', () {
    test('keeps location_id and sector_id and maps district to area', () {
      final store = StoreModel.fromJson({
        'id': '2',
        'location_id': '18',
        'name': 'سوبر ماركت كعكة',
        'address': 'شارع الجميلية',
        'district': 'الجميلية',
        'sector_id': '2',
        'sector': 'الكتلة الثانية',
        'is_verified': true,
        'prices_count': 12,
      });

      expect(store.locationId, '18');
      expect(store.sectorId, '2');
      // `district` is the canonical field; `area` is the display alias.
      expect(store.area, 'الجميلية');
      expect(store.sector, 'الكتلة الثانية');
      expect(store.isVerified, isTrue);
      expect(store.pricesCount, 12);
    });

    test('ids survive a copyWith', () {
      final store = StoreModel(
        id: '2',
        name: 'x',
        address: 'y',
        area: 'z',
        sector: 's',
        locationId: '18',
        sectorId: '2',
      );

      final updated = store.copyWith(isVerified: true);

      expect(updated.locationId, '18');
      expect(updated.sectorId, '2');
    });
  });

  group('ProductModel', () {
    test('parses the computed aggregate fields', () {
      final product = ProductModel.fromJson({
        'id': '2',
        'name': 'برغل',
        'category': 'حبوب ومطاحن',
        'official_price': 85,
        'real_price': 92.65,
        'avg_price': 93.16,
        'unit': 'كيلوغرام',
        'unit_id': '1',
        'amount': 1,
        'prices_count': 7,
        'change_percent': 9,
        'is_price_up': true,
      });

      expect(product.officialPrice, 85);
      expect(product.realPrice, 92.65);
      expect(product.avgPrice, 93.16);
      expect(product.unitId, '1');
      expect(product.amount, 1);
      expect(product.pricesCount, 7);
      expect(product.changePercent, 9);
      expect(product.isPriceUp, isTrue);
    });

    test('a product with no market data reads as zeroes', () {
      final product = ProductModel.fromJson({
        'id': '5',
        'name': 'زيت زيتون',
        'category': 'زيوت',
        'official_price': 0,
        'real_price': 0,
        'avg_price': 0,
        'prices_count': 0,
        'change_percent': 0,
        'is_price_up': false,
      });

      expect(product.realPrice, 0);
      expect(product.pricesCount, 0);
      expect(product.isPriceUp, isFalse);
    });
  });

  group('PriceEntry', () {
    test('parses a submitted price without depending on a status field', () {
      // The backend deliberately has no `status` column for prices.
      final price = PriceEntry.fromJson({
        'id': '108',
        'product_id': '18',
        'product_name': 'مربى المشمش',
        'store_id': '3',
        'store_name': 'سوبر ماركت القلعة',
        'store_area': 'الفرافرة',
        'location_id': '4',
        'sector_id': '1',
        'price': 32.5,
        'unit': 'كيلوغرام',
        'unit_id': '1',
        'amount': 2,
        'brand': 'الخير',
        'brand_id': '2',
        'submitted_by': 'أحمد',
        'submitted_at': '2026-09-08T15:04:00Z',
        'thumbs_up': 4,
        'thumbs_down': 1,
        'total_ratings': 5,
      });

      expect(price.id, '108');
      expect(price.productId, '18');
      expect(price.storeId, '3');
      expect(price.unitId, '1');
      expect(price.brandId, '2');
      // The wire field is `amount`; the Dart field kept the name `quantity`.
      expect(price.quantity, 2);
      expect(price.thumbsUp, 4);
      expect(price.thumbsDown, 1);
      expect(price.totalRatings, 5);
      expect(price.submittedAt.toUtc().toIso8601String(),
          startsWith('2026-09-08T15:04:00'));
    });

    test('the vote counters update through copyWith', () {
      final price = PriceEntry(
        id: '1',
        productName: 'x',
        storeName: 'y',
        storeArea: 'z',
        price: 10,
        unit: 'كغ',
        quantity: 1,
        submittedBy: 'a',
        submittedAt: DateTime.utc(2026, 9, 8),
      );

      final voted = price.copyWith(thumbsUp: 1, totalRatings: 1);

      expect(voted.thumbsUp, 1);
      expect(voted.totalRatings, 1);
      expect(voted.id, '1');
    });
  });

  group('LocationModel', () {
    test('district is canonical and area is the alias', () {
      final location = LocationModel.fromJson({
        'id': '18',
        'sector_id': '2',
        'sector': 'الكتلة الثانية',
        'district': 'الجميلية',
        'area': 'الجميلية',
        'stores_count': 2,
      });

      expect(location.id, '18');
      expect(location.sectorId, '2');
      expect(location.area, 'الجميلية');
      expect(location.storesCount, 2);
    });
  });

  group('ReportType', () {
    test('exposes exactly the three values the database CHECK allows', () {
      expect(ReportType.all, [
        'سعر مبالغ فيه',
        'سعر غير صحيح',
        'معلومات غير صحيحة',
      ]);
    });

    test('only the wrong-information type carries a description', () {
      expect(ReportType.allowsDescription(ReportType.wrongInfo), isTrue);
      expect(ReportType.allowsDescription(ReportType.overpriced), isFalse);
      expect(ReportType.allowsDescription(ReportType.wrongPrice), isFalse);
    });
  });

  group('OfficialPrice', () {
    test('parses amount and the change timestamp', () {
      final official = OfficialPrice.fromJson({
        'id': '6',
        'product_id': '2',
        'product_name': 'برغل',
        'unit_id': '1',
        'unit': 'كيلوغرام',
        'amount': 1,
        'price': 85,
        'created_at': '2026-08-27T09:05:00Z',
      });

      expect(official.productId, '2');
      expect(official.unitId, '1');
      expect(official.quantity, 1);
      expect(official.price, 85);
      expect(official.updatedAt.toUtc().month, 8);
    });

    test('history entries parse changed_at', () {
      final entry = OfficialPriceHistoryEntry.fromJson({
        'id': '4',
        'price': 79.9,
        'changed_at': '2026-07-10T09:05:00Z',
      });

      expect(entry.price, 79.9);
      expect(entry.changedAt.toUtc().year, 2026);
    });
  });
}
