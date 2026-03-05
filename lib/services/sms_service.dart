// flutter_foreground_task v8 — no flutter/material needed here
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:telephony/telephony.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/payment.dart';
import '../services/parsers/telebirr_parser.dart';
import '../services/parsers/cbe_parser.dart';
import '../services/queue_service.dart';
import '../services/api_service.dart';
import '../utils/notification_helper.dart';

// ── Top-level callback required by flutter_foreground_task ───────────────────
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SmsTaskHandler());
}

// ── Task handler (runs in isolate) ────────────────────────────────────────────
class SmsTaskHandler extends TaskHandler {
  final Telephony _telephony = Telephony.backgroundInstance;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _registerSmsListener();
    _listenConnectivity();
  }

  void _registerSmsListener() {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await _handleSms(message);
      },
      onBackgroundMessage: _backgroundSmsHandler,
      listenInBackground: true,
    );
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) async {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (connected) await SmsService.syncPending();
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Periodic sync attempt every 15 min
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected) await SmsService.syncPending();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

// ── Background SMS handler (top-level — required by telephony) ────────────────
@pragma('vm:entry-point')
Future<void> _backgroundSmsHandler(SmsMessage message) async {
  await _handleSms(message);
}

Future<void> _handleSms(SmsMessage message) async {
  final address = message.address ?? '';
  final body = message.body ?? '';

  Payment? payment =
      TelebirrParser.parse(body, address) ?? CbeParser.parse(body, address);

  if (payment == null) return; // Not a recognized payment SMS

  try {
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected) {
      await ApiService.reportPayment(payment);
      final saved = await QueueService.enqueue(
          payment.copyWith(syncStatus: SyncStatus.synced));
      await NotificationHelper.showSynced(saved.amount, saved.referenceNumber);
    } else {
      await QueueService.enqueue(payment);
      final count = await QueueService.getPendingCount();
      await NotificationHelper.showPending(count);
    }
  } catch (_) {
    await QueueService.enqueue(payment);
    final count = await QueueService.getPendingCount();
    await NotificationHelper.showPending(count);
  }
}

// ── Public service API ────────────────────────────────────────────────────────
class SmsService {
  static bool _running = false;
  static bool get isRunning => _running;

  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'payshield_monitor',
        channelName: 'PayShield',
        channelDescription:
            'PayShield monitors SMS for incoming CBE & Telebirr payments',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(900000), // 15 min
        autoRunOnBoot: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startForegroundService() async {
    if (_running) return;
    try {
      await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'PayShield Active',
        notificationText: 'Watching for Telebirr & CBE payments…',
        callback: startCallback,
      );
      _running = true;
    } catch (_) {
      // Service might already be running
      _running = await FlutterForegroundTask.isRunningService;
    }
  }

  static Future<void> stopForegroundService() async {
    await FlutterForegroundTask.stopService();
    _running = false;
  }

  /// Request battery optimization exemption dialog
  static Future<void> requestBatteryExemption() async {
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  /// Retry all pending queue items
  static Future<void> syncPending() async {
    final pending = await QueueService.getPendingPayments();
    if (pending.isEmpty) return;

    for (final payment in pending) {
      try {
        await ApiService.reportPayment(payment);
        await QueueService.updateStatus(payment.id!, SyncStatus.synced);
      } catch (_) {
        await QueueService.updateStatus(payment.id!, SyncStatus.failed);
      }
    }

    final remaining = await QueueService.getPendingCount();
    if (remaining == 0) {
      await NotificationHelper.dismissPending();
    } else {
      await NotificationHelper.showPending(remaining);
    }
  }

  /// Request SMS read/receive permissions at runtime
  static Future<bool> requestSmsPermissions() async {
    final result = await Telephony.instance.requestPhoneAndSmsPermissions;
    return result == true;
  }
}
