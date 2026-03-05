import '../../models/payment.dart';

/// Parses Telebirr payment SMS messages.
///
/// Telebirr SMS typically comes from sender "127" and looks like:
///   "Confirmed. ETB 500.00 received from 0911234567 on 01/03/2026 20:00:00.
///    Ref: TID1234567890. Your balance is ETB 1,250.00."
///
/// We support common Telebirr SMS variants with multiple regex patterns.
class TelebirrParser {
  static const String senderAddress = '127';

  /// Returns a [Payment] if the SMS is a recognized Telebirr payment, else null.
  static Payment? parse(String body, String sender) {
    final normalizedSender = sender.replaceAll('+', '').trim();
    if (!_isTelebirrSender(normalizedSender)) return null;

    final normalized = body.replaceAll('\n', ' ').trim();

    // Try each pattern variant
    return _parseVariantA(normalized) ??
        _parseVariantB(normalized) ??
        _parseVariantC(normalized) ??
        _parseVariantD(normalized);
  }

  static bool _isTelebirrSender(String sender) {
    return sender == '127' || sender.toLowerCase().contains('telebirr');
  }

  /// Variant A: "Confirmed. ETB 500.00 received from 0911... Ref: TID..."
  static Payment? _parseVariantA(String body) {
    final amountMatch = RegExp(
      r'ETB\s*([\d,]+\.?\d*)\s*received',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'received from\s*(\+?[\d]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'Ref[:\s]+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final dateMatch = RegExp(
      r'on\s*(\d{2}/\d{2}/\d{4})\s*(\d{2}:\d{2}:\d{2})',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    DateTime timestamp = DateTime.now();
    if (dateMatch != null) {
      try {
        final dateParts = dateMatch.group(1)!.split('/');
        final timeParts = dateMatch.group(2)!.split(':');
        timestamp = DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );
      } catch (_) {}
    }

    return Payment(
      source: PaymentSource.telebirr,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: timestamp,
      rawSms: body,
    );
  }

  /// Variant B: "You have received ETB 500.00 from 0911... Reference: TXN..."
  static Payment? _parseVariantB(String body) {
    final amountMatch = RegExp(
      r'received\s+ETB\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'from\s*(\+?[\d]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'Reference[:\s]+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    return Payment(
      source: PaymentSource.telebirr,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: DateTime.now(),
      rawSms: body,
    );
  }

  /// Variant C: Generic — catches any SMS mentioning ETB + Ref/TID
  static Payment? _parseVariantC(String body) {
    final amountMatch = RegExp(
      r'ETB\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'(?:Ref|TID|Transaction ID)[:\s]+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    return Payment(
      source: PaymentSource.telebirr,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      timestamp: DateTime.now(),
      rawSms: body,
    );
  }

  /// Variant D: "You have received ETB 4,400.00 from Yeabtsega Abate(2519****8875) ... Your transaction number is DC30DSL76U."
  static Payment? _parseVariantD(String body) {
    final amountMatch = RegExp(
      r'received\s+ETB\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'from\s+([a-zA-Z\s]+?)\s*\(\d+\*\*\*\*\d+\)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'transaction number is\s+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    return Payment(
      source: PaymentSource.telebirr,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: DateTime.now(),
      rawSms: body,
    );
  }
}
