import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/app.dart';
import 'package:campus_nav/data/models/campus_data.dart';
import 'package:campus_nav/data/repositories/repository_providers.dart';
import 'package:campus_nav/data/repositories/room_details_repository.dart';
import 'package:campus_nav/features/map/campus_map_screen.dart';
import 'package:campus_nav/features/route/route_providers.dart';
import 'package:campus_nav/features/start/start_point_screen.dart';
import 'package:campus_nav/services/routing/pathfinder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Smoke tests: build the real widget tree on a small and a large phone and
/// walk the entry flow, so layout overflows and provider wiring break loudly.
void main() {
  late Directory tempDir;
  late Box<String> box;
  late CampusData data;
  late Map<String, RoomDetails> details;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('campus_nav_smoke');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('campus_nav');
    data = CampusData.fromJson(
      jsonDecode(File('assets/data/buildings.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    details = const RoomDetailsRepository().parse(
      File('assets/data/room_details.json').readAsStringSync(),
    );
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await box.close();
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  overrides() => [
    campusDataProvider.overrideWithValue(data),
    roomDetailsProvider.overrideWithValue(details),
    storageBoxProvider.overrideWithValue(box),
    pathfinderProvider.overrideWithValue(Pathfinder(data)),
  ];

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets(
      'entry flow runs at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await setSize(tester, size);
        await tester.pumpWidget(
          ProviderScope(overrides: overrides(), child: const CampusNavApp()),
        );
        await tester.pumpAndSettle();

        expect(find.text('CAMPUS NAV'), findsOneWidget);
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();

        expect(find.text('Find rooms'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back!'), findsOneWidget);
        await tester.tap(find.text('Continue as guest'));
        await tester.pumpAndSettle();

        expect(find.text('Home'), findsWidgets);
        expect(find.text("Today's Classes"), findsOneWidget);
        expect(find.text('Upload Study Load'), findsOneWidget);
      },
    );
  }

  testWidgets('map shows a building sheet with real room data', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(
          home: CampusMapScreen(initialBuildingId: 'stcs'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Campus Map'), findsOneWidget);
    expect(
      find.text('School of Technology and Computer Studies'),
      findsOneWidget,
    );
    // The sheet lists floors top-down; the 4th floor rooms are on screen.
    expect(find.text('T-401'), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
  });

  testWidgets('a building with no rooms says so', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(
          home: CampusMapScreen(initialBuildingId: 'student'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student Center'), findsOneWidget);
    expect(find.text('No room details yet'), findsOneWidget);
  });

  testWidgets('starting point lists every campus building', (tester) async {
    await setSize(tester, const Size(390, 844));
    final container = ProviderContainer(overrides: overrides());
    addTearDown(container.dispose);
    container
        .read(destinationProvider.notifier)
        .set(Destination(buildingId: data.buildings.first.id));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StartPointScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buildings'), findsOneWidget);
    for (final building in data.buildings) {
      expect(
        find.text(building.name),
        findsWidgets,
        reason: '${building.name} is missing from starting points',
      );
    }
  });
}
