import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int _syncedChannel = 1;
  static const int _pendingChannel = 2;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  /// Shows "Payment synced ✅" notification
  static Future<void> showSynced(double amount, String reference) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payment_synced',
        'Payment Synced',
        channelDescription: 'Notifies when a payment is reported to the server',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(
      _syncedChannel,
      'Payment Synced ✅',
      'ETB ${amount.toStringAsFixed(2)} (Ref: $reference) reported successfully.',
      details,
    );
  }

  /// Shows "X pending payments" notification
  static Future<void> showPending(int count) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'payment_pending',
        'Pending Payments',
        channelDescription: 'Shows how many payments are waiting to be synced',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        ongoing: false,
      ),
    );
    await _plugin.show(
      _pendingChannel,
      'Pending Payments ⏳',
      '$count payment${count == 1 ? '' : 's'} waiting to sync. Connect to internet to sync.',
      details,
    );
  }

  /// Dismiss pending notification (after all synced)
  static Future<void> dismissPending() async {
    await _plugin.cancel(_pendingChannel);
  }
}
