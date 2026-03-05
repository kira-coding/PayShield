import 'package:flutter_test/flutter_test.dart';
import 'package:payment_verifier/services/parsers/cbe_parser.dart';
import 'package:payment_verifier/models/payment.dart';

void main() {
  group('CbeParser Tests', () {
    test('Parse New Message Format (Variant D)', () {
      const body =
          'Dear Kininet your Account 1*****9545 has been Credited with ETB 50.00 from Mr Robel, on 24/02/2026 at 19:57:07 with Ref No FT26055F3FYB Your Current Balance is ETB 712.39. Thank you for Banking with CBE! https://apps.cbe.com.et:100/?id=FT26055F3FYB47949545';
      const sender = 'CBE';

      final payment = CbeParser.parse(body, sender);

      expect(payment, isNotNull);
      expect(payment!.source, PaymentSource.cbe);
      expect(payment.amount, 50.0);
      expect(payment.referenceNumber, 'FT26055F3FYB');
      expect(payment.senderPhone, 'Mr Robel');
      expect(payment.timestamp.year, 2026);
      expect(payment.timestamp.month, 2);
      expect(payment.timestamp.day, 24);
      expect(payment.timestamp.hour, 19);
      expect(payment.timestamp.minute, 57);
      expect(payment.timestamp.second, 7);
    });

    test('Non-CBE sender should return null', () {
      const body =
          'Dear Kininet your Account 1*****9545 has been Credited with ETB 50.00 from Mr Robel...';
      const sender = 'UNKNOWN';

      final payment = CbeParser.parse(body, sender);

      expect(payment, isNull);
    });
  });
}
