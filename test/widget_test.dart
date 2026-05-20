import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physio_therapy_clinic/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame inside ProviderScope.
    await tester.pumpWidget(
      const ProviderScope(
        child: PhysioClinicApp(),
      ),
    );

    // Verify that the app launches and does not crash.
    expect(find.byType(PhysioClinicApp), findsOneWidget);

    // Pump once to trigger initState
    await tester.pump();

    // Advance clock by 1.6 seconds to let the splash screen delay complete
    await tester.pump(const Duration(milliseconds: 1600));

    // Pump again to handle the resulting GoRouter navigation frames
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(milliseconds: 500),
    );
  });
}
