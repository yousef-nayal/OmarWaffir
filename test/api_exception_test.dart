import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffir_app/core/network/api_exception.dart';

/// The API answers every failure with an Arabic message aimed at the user.
/// These tests pin the rule that the app shows that message rather than a
/// generic one invented on the client.
void main() {
  DioException responseError(int status, Map<String, dynamic>? body) {
    final options = RequestOptions(path: '/auth/login');
    return DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    );
  }

  group('401', () {
    test('shows the server message instead of "session ended"', () {
      // Regression: a wrong password on the login screen used to report
      // "انتهت جلستك" - an expired session the user never had.
      final e = ApiException.fromDio(responseError(401, {
        'success': false,
        'message': 'رقم الهاتف أو كلمة المرور غير صحيحة',
      }));

      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'رقم الهاتف أو كلمة المرور غير صحيحة');
    });

    test('falls back to the generic text when the body carries no message', () {
      final e = ApiException.fromDio(responseError(401, null));

      expect(e.message, contains('انتهت جلستك'));
    });
  });

  group('403', () {
    test('a blocked account says so', () {
      final e = ApiException.fromDio(responseError(403, {
        'success': false,
        'message': 'الحساب محظور، يرجى التواصل مع الإدارة',
      }));

      expect(e.type, ApiErrorType.forbidden);
      expect(e.message, 'الحساب محظور، يرجى التواصل مع الإدارة');
    });

    test('an unverified phone says so', () {
      final e = ApiException.fromDio(responseError(403, {
        'success': false,
        'message': 'يجب تأكيد رقم الهاتف أولاً',
      }));

      expect(e.message, 'يجب تأكيد رقم الهاتف أولاً');
    });

    test('rating your own price says so', () {
      final e = ApiException.fromDio(responseError(403, {
        'success': false,
        'message': 'لا يمكنك تقييم سعر أضفته بنفسك',
      }));

      expect(e.message, 'لا يمكنك تقييم سعر أضفته بنفسك');
    });

    test('falls back to the generic text when the body carries no message', () {
      final e = ApiException.fromDio(responseError(403, null));

      expect(e.message, contains('لا تملك صلاحية'));
    });
  });

  group('422', () {
    test('keeps the message and the field errors', () {
      final e = ApiException.fromDio(responseError(422, {
        'success': false,
        'message': 'رقم الهاتف مستخدم مسبقاً',
        'errors': {
          'phone_number': ['رقم الهاتف مستخدم مسبقاً'],
        },
      }));

      expect(e.type, ApiErrorType.validation);
      expect(e.message, 'رقم الهاتف مستخدم مسبقاً');
      expect(e.errors?['phone_number'], isNotNull);
    });
  });

  group('other statuses', () {
    test('409 conflicts surface the server message', () {
      final e = ApiException.fromDio(responseError(409, {
        'success': false,
        'message': 'لا يمكن الحذف لأن العنصر مستخدم في بيانات أخرى',
      }));

      expect(e.message, 'لا يمكن الحذف لأن العنصر مستخدم في بيانات أخرى');
    });

    test('a 500 hides the server detail behind a generic message', () {
      // Internal failures must not leak implementation detail to the user,
      // but the original text is kept for developers.
      final e = ApiException.fromDio(responseError(500, {
        'success': false,
        'message': 'SQLSTATE[42883]: Undefined function',
      }));

      expect(e.type, ApiErrorType.server);
      expect(e.message, isNot(contains('SQLSTATE')));
      expect(e.devMessage, contains('SQLSTATE'));
    });

    test('a connection failure is reported as a network problem', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: RequestOptions(path: '/products'),
        type: DioExceptionType.connectionError,
      ));

      expect(e.type, ApiErrorType.network);
      expect(e.message, contains('الاتصال'));
    });
  });
}
