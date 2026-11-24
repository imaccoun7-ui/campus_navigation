import 'package:campus_nav/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash screen renders the app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CampusNavApp()));
    await tester.pump();

    expect(find.text('CAMPUS NAV'), findsOneWidget);
  });
}
