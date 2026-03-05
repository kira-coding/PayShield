enum SyncStatus { pending, synced, failed }

enum PaymentSource { telebirr, cbe, unknown }

class Payment {
  final int? id;
  final PaymentSource source;
  final String referenceNumber;
  final double amount;
  final String? senderPhone;
  final DateTime timestamp;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final String rawSms;

  Payment({
    this.id,
    required this.source,
    required this.referenceNumber,
    required this.amount,
    this.senderPhone,
    required this.timestamp,
    this.syncStatus = SyncStatus.pending,
    DateTime? createdAt,
    required this.rawSms,
  }) : createdAt = createdAt ?? DateTime.now();

  Payment copyWith({
    int? id,
    PaymentSource? source,
    String? referenceNumber,
    double? amount,
    String? senderPhone,
    DateTime? timestamp,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    String? rawSms,
  }) {
    return Payment(
      id: id ?? this.id,
      source: source ?? this.source,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      amount: amount ?? this.amount,
      senderPhone: senderPhone ?? this.senderPhone,
      timestamp: timestamp ?? this.timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      rawSms: rawSms ?? this.rawSms,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source.name,
      'reference_number': referenceNumber,
      'amount': amount,
      'sender_phone': senderPhone,
      'timestamp': timestamp.toIso8601String(),
      'sync_status': syncStatus.name,
      'created_at': createdAt.toIso8601String(),
      'raw_sms': rawSms,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      source: PaymentSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => PaymentSource.unknown,
      ),
      referenceNumber: map['reference_number'],
      amount: (map['amount'] as num).toDouble(),
      senderPhone: map['sender_phone'],
      timestamp: DateTime.parse(map['timestamp']),
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at']),
      rawSms: map['raw_sms'] ?? '',
    );
  }

  /// Payload sent to the API
  Map<String, dynamic> toApiJson() {
    return {
      'source': source.name,
      'reference': referenceNumber,
      'amount': amount,
      'sender_phone': senderPhone,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Payment(id=$id, source=${source.name}, ref=$referenceNumber, amount=$amount, status=${syncStatus.name})';
}
