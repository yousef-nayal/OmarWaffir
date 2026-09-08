import '../../../models/models.dart';
import '../api_client.dart';

/// إشعارات داخل التطبيق — راجع docs/FINAL_API_CONTRACT.md → "Notifications".
///
/// ✅ جديد — كانت الصفحة الرئيسية تعرض إشعارات المستخدم من
/// GET /admin/recent-activity، وهو مسار إداري محمي بـ role:1، فكان يعود
/// دائماً بـ 403 لأي مستخدم عادي وتظهر قائمة الإشعارات فارغة. الإشعارات
/// الحقيقية للمستخدم لها مسارها الخاص، وهذا ما تستخدمه الشاشة الآن.
class NotificationService {
  final ApiClient _api;
  NotificationService({ApiClient? api}) : _api = api ?? ApiClient();

  /// GET /notifications
  Future<List<AppNotification>> getNotifications({int perPage = 20}) {
    return _api.get<List<AppNotification>>(
      '/notifications',
      queryParameters: {'per_page': perPage},
      fromJson: (json) {
        final list = (json as Map<String, dynamic>)['data'] as List? ?? [];
        return list.map((e) => AppNotification.fromJson(e)).toList();
      },
    );
  }

  /// GET /notifications/unread-count
  Future<int> getUnreadCount() {
    return _api.get<int>(
      '/notifications/unread-count',
      fromJson: (json) {
        final data = (json as Map<String, dynamic>)['data'];
        if (data is Map<String, dynamic>) {
          return data['unread_count'] as int? ?? 0;
        }
        return 0;
      },
    );
  }

  /// PATCH /notifications/{id}/read
  Future<void> markRead(String id) =>
      _api.patch<void>('/notifications/$id/read');

  /// PATCH /notifications/read-all
  Future<void> markAllRead() => _api.patch<void>('/notifications/read-all');
}
