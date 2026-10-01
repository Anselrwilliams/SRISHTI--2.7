import 'package:flutter_test/flutter_test.dart';
import 'package:srishti_volunteer/main.dart';

void main() {
  testWidgets('App initializes and loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SrishtiVolunteerApp());
    await tester.pumpAndSettle();

    // Verify app rendered properly
    expect(find.byType(SrishtiVolunteerApp), findsOneWidget);
  });
}
