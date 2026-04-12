import 'package:flutter_test/flutter_test.dart';
import 'package:tabdeb/flutter_main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DebateTournamentApp());

    // Verify that the home screen loads
    expect(find.text('Welcome to the Debate Tournament Tab System!'),
        findsOneWidget);
    expect(find.text('Create Tournament'), findsOneWidget);
    expect(find.text('Run Tournament'), findsOneWidget);
    expect(find.text('View Data'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
  });
}
