import '../../models/payment.dart';

/// Parses CBE Birr payment SMS messages.
///
/// CBE Birr SMS typically comes from sender "CBE" or "8397" and looks like:
///   "Dear Customer, ETB 500.00 has been credited to your account 100XXXXXXXX
///    from 100XXXXXXXX on 01/03/2026. Tran ID: 123456789."
///
/// or:
///   "You have received 500.00 ETB from Account No:100XXXXXXXX.
///    Transaction Reference: REF123456789."
class CbeParser {
  static const List<String> senderAddresses = ['CBE', '8397', 'CBEBIRR'];

  static Payment? parse(String body, String sender) {
    final normalizedSender = sender.toUpperCase().trim();
    if (!_isCbeSender(normalizedSender)) return null;

    final normalized = body.replaceAll('\n', ' ').trim();

    return _parseVariantA(normalized) ??
        _parseVariantB(normalized) ??
        _parseVariantC(normalized) ??
        _parseVariantD(normalized);
  }

  static bool _isCbeSender(String sender) {
    return senderAddresses.any((s) => sender.contains(s)) ||
        sender.toLowerCase().contains('cbe');
  }

  /// Variant A: "ETB 500.00 has been credited... Tran ID: ..."
  static Payment? _parseVariantA(String body) {
    final amountMatch = RegExp(
      r'ETB\s*([\d,]+\.?\d*)\s*has been credited',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'from\s*([\dA-Z]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'Tran(?:saction)?\s*ID[:\s]+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final dateMatch = RegExp(
      r'on\s*(\d{2}/\d{2}/\d{4})',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    DateTime timestamp = DateTime.now();
    if (dateMatch != null) {
      try {
        final parts = dateMatch.group(1)!.split('/');
        timestamp = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      } catch (_) {}
    }

    return Payment(
      source: PaymentSource.cbe,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: timestamp,
      rawSms: body,
    );
  }

  /// Variant B: "You have received 500.00 ETB from Account No:... Reference: ..."
  static Payment? _parseVariantB(String body) {
    final amountMatch = RegExp(
      r'received\s*([\d,]+\.?\d*)\s*ETB',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'Account No[:\s]*([\dA-Z]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'(?:Transaction\s*)?Reference[:\s]+([A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    return Payment(
      source: PaymentSource.cbe,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: DateTime.now(),
      rawSms: body,
    );
  }

  /// Variant C: Generic CBE — amount + any reference
  static Payment? _parseVariantC(String body) {
    final amountMatch = RegExp(
      r'([\d,]+\.?\d*)\s*ETB|ETB\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'(?:Ref|TID|Trans(?:action)?)[:\s]+([A-Z0-9]{4,})',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final raw = (amountMatch.group(1) ?? amountMatch.group(2) ?? '0')
        .replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null) return null;

    return Payment(
      source: PaymentSource.cbe,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      timestamp: DateTime.now(),
      rawSms: body,
    );
  }

  /// Variant D: "Dear [Name] your Account [Acc] has been Credited with ETB [Amount] from [Sender], on [Date] at [Time] with Ref No [Ref] ... "
  static Payment? _parseVariantD(String body) {
    // Dear Kininet your Account 1*****9545 has been Credited with ETB 50.00 from Mr Robel, on 24/02/2026 at 19:57:07 with Ref No FT26055F3FYB Your Current Balance is ETB 712.39.
    final amountMatch = RegExp(
      r'Credited with ETB\s*([\d,]+\.?\d*)',
      caseSensitive: false,
    ).firstMatch(body);
    final senderMatch = RegExp(
      r'from\s+([^,]+)',
      caseSensitive: false,
    ).firstMatch(body);
    final refMatch = RegExp(
      r'Ref No\s+([A-Z0-9]{10,})',
      caseSensitive: false,
    ).firstMatch(body);
    final dateTimeMatch = RegExp(
      r'on\s*(\d{2}/\d{2}/\d{4})\s*at\s*(\d{2}:\d{2}:\d{2})',
      caseSensitive: false,
    ).firstMatch(body);

    if (amountMatch == null || refMatch == null) return null;

    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null) return null;

    DateTime timestamp = DateTime.now();
    if (dateTimeMatch != null) {
      try {
        final dateParts = dateTimeMatch.group(1)!.split('/');
        final timeParts = dateTimeMatch.group(2)!.split(':');
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
      source: PaymentSource.cbe,
      referenceNumber: refMatch.group(1)!.trim(),
      amount: amount,
      senderPhone: senderMatch?.group(1)?.trim(),
      timestamp: timestamp,
      rawSms: body,
    );
  }
}
