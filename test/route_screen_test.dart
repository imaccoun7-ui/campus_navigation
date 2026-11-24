import 'package:campus_nav/data/models/building.dart';
import 'package:campus_nav/features/route/route_providers.dart';
import 'package:campus_nav/features/route/route_screen.dart';
import 'package:campus_nav/services/routing/pathfinder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route instruction appears only once in the details', (
    tester,
  ) async {
    final building = Building(
      id: 'destination',
      name: 'Destination Building',
      poly: const <Offset>[Offset.zero, Offset(10, 0), Offset(10, 10)],
      floors: const [],
    );
    const firstStep = 'Head east from First Gate.';
    final plan = RoutePlan(
      path: const RoutePath(
        points: <Offset>[Offset.zero, Offset(10, 0)],
        pixels: 10,
      ),
      steps: const <String>[firstStep, 'Continue to the entrance.'],
      destination: building,
      startLabel: 'First Gate',
    );
    final container = ProviderContainer(
      overrides: [routePlanProvider.overrideWithValue(plan)],
    );
    addTearDown(container.dispose);
    container
        .read(destinationProvider.notifier)
        .set(const Destination(buildingId: 'destination'));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RouteScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(firstStep), findsOneWidget);
    expect(find.text('Destination Building'), findsOneWidget);
    expect(find.text('From First Gate'), findsNothing);
  });
}
