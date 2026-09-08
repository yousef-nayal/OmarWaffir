import 'package:flutter_test/flutter_test.dart';
import 'package:waffir_app/core/config/app_config.dart';
import 'package:waffir_app/features/auth/data/auth_service.dart';

/// The registration lifecycle contract.
///
/// Registration must NOT hand out a session: the account only becomes usable
/// after the phone number is verified. These tests pin the response shapes the
/// two endpoints return so a regression on either side is caught here.
void main() {
  group('AppConfig', () {
    test('mock data is off unless it is explicitly switched on at build time',
        () {
      // Guards against shipping a build that quietly shows demo data.
      expect(AppConfig.useMockData, isFalse);
    });
  });

  group('RegistrationResult', () {
    test('POST /auth/register carries no tokens', () {
      final result = RegistrationResult.fromJson({
        'success': true,
        'message': 'تم إرسال رمز التحقق',
        'data': {
          'requires_verification': true,
          'phone_number': '0991112233',
        },
      });

      expect(result.requiresVerification, isTrue);
      expect(result.phone, '0991112233');
    });
  });

  group('AuthResult', () {
    test('POST /auth/verify-otp returns the token pair and the user', () {
      final result = AuthResult.fromJson({
        'success': true,
        'message': 'تم تأكيد رقم الهاتف بنجاح',
        'data': {
          'access_token': 'access-token-value',
          'refresh_token': 'refresh-token-value',
          'user': {
            'id': '9',
            'name': 'مستخدم جديد',
            'phone_number': '0991112233',
            'role': 0,
            'location_id': '18',
            'is_active': true,
          },
        },
      });

      expect(result.accessToken, 'access-token-value');
      expect(result.refreshToken, 'refresh-token-value');
      expect(result.user.id, '9');
      expect(result.user.roleLevel, 0);
      expect(result.user.locationId, '18');
    });

    test('the admin login response is read the same way', () {
      final result = AuthResult.fromJson({
        'success': true,
        'data': {
          'access_token': 'a',
          'refresh_token': 'r',
          'user': {'id': '2', 'name': 'مسؤول', 'role': 2},
        },
      });

      // Role level 2 is what unlocks the super-admin only screens.
      expect(result.user.roleLevel, 2);
      expect(result.user.role, 'admin');
    });
  });
}
