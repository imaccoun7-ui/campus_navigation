import 'package:campus_nav/features/auth/login_screen.dart';
import 'package:campus_nav/services/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('password visibility can be toggled on the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    TextField passwordField() =>
        tester.widgetList<TextField>(find.byType(TextField)).last;

    expect(passwordField().obscureText, isTrue);
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();

    expect(passwordField().obscureText, isTrue);
  });
}
