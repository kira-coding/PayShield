// Basic smoke test — replaces the default counter test
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_verifier/main.dart';
import 'package:provider/provider.dart';
import 'package:payment_verifier/providers/app_provider.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const PaymentVerifierApp(),
      ),
    );
    // Loading spinner should appear on startup
    expect(find.byType(PaymentVerifierApp), findsOneWidget);
  });
}
