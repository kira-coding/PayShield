import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../services/queue_service.dart';
import '../services/sms_service.dart';

class AppProvider extends ChangeNotifier {
  List<Payment> _payments = [];
  int _pendingCount = 0;
  bool _serviceRunning = false;
  bool _isSyncing = false;
  String _domain = '';
  List<String> _senderFilters = ['127', 'CBE', 'CBEBIRR', '8397'];

  List<Payment> get payments => _payments;
  int get pendingCount => _pendingCount;
  bool get serviceRunning => _serviceRunning;
  bool get isSyncing => _isSyncing;
  String get domain => _domain;
  List<String> get senderFilters => _senderFilters;

  Future<void> init() async {
    _domain = await ApiService.getDomain();
    await _loadSenderFilters();
    await refreshPayments();
    _serviceRunning = SmsService.isRunning;
    notifyListeners();
  }

  Future<void> refreshPayments() async {
    _payments = await QueueService.getAllPayments();
    _pendingCount =
        _payments.where((p) => p.syncStatus == SyncStatus.pending).length;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    await SmsService.syncPending();
    await refreshPayments();
    _isSyncing = false;
    notifyListeners();
  }

  Future<void> startService() async {
    await SmsService.startForegroundService();
    _serviceRunning = true;
    notifyListeners();
  }

  Future<void> stopService() async {
    await SmsService.stopForegroundService();
    _serviceRunning = false;
    notifyListeners();
  }

  Future<void> saveDomain(String value) async {
    await ApiService.saveDomain(value);
    _domain = await ApiService.getDomain();
    notifyListeners();
  }

  Future<void> saveSenderFilters(List<String> filters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('sender_filters', filters);
    _senderFilters = filters;
    notifyListeners();
  }

  Future<void> _loadSenderFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('sender_filters');
    if (saved != null && saved.isNotEmpty) _senderFilters = saved;
  }

  Future<void> logout() async {
    await ApiService.clearApiKey();
    await stopService();
  }
}
