import 'dart:ui';

import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/data/models/building.dart';
import 'package:campus_nav/data/models/campus_data.dart';
import 'package:campus_nav/data/models/road_graph.dart';
import 'package:campus_nav/services/routing/pathfinder.dart';
import 'package:campus_nav/services/routing/steps_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CampusData data;
  late Pathfinder pathfinder;

  setUpAll(() {
    final raw = File('assets/data/buildings.json').readAsStringSync();
    data = CampusData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    pathfinder = Pathfinder(data);
  });

  test('steps describe the walk and the destination room', () {
    final building = data.buildingById('stcs')!;
    final room = building.roomNamed('T-201 - AutoCAD Lab');
    final route = pathfinder.findRoute(
      fromNodeId: pathfinder.gateNodeId('First Gate'),
      toBuildingId: building.id,
    )!;

    final steps = const StepsBuilder().build(
      path: route,
      destination: building,
      room: room,
      startLabel: 'First Gate',
      data: data,
    );

    expect(steps, isNotEmpty);
    expect(steps.length, lessThanOrEqualTo(6));
    expect(steps.first, contains('First Gate'));
    expect(steps.last, anyOf(contains('T-201'), contains(building.name)));
  });

  test('steps stay short and readable for every building', () {
    final start = pathfinder.gateNodeId('First Gate');
    for (final building in data.buildings) {
      final route = pathfinder.findRoute(
        fromNodeId: start,
        toBuildingId: building.id,
      )!;
      final steps = const StepsBuilder().build(
        path: route,
        destination: building,
        room: null,
        startLabel: 'First Gate',
        data: data,
      );
      expect(steps.length, lessThanOrEqualTo(6), reason: building.name);
      for (final step in steps) {
        expect(step.trim(), isNotEmpty);
        expect(step.length, lessThan(140), reason: step);
      }
    }
  });

  test('straight routes use ordered landmarks instead of invented turns', () {
    final firstLandmark = Building(
      id: 'first_landmark',
      name: 'First Landmark',
      poly: const <Offset>[
        Offset(20, -10),
        Offset(40, -10),
        Offset(40, 10),
        Offset(20, 10),
      ],
      floors: const [],
    );
    final secondLandmark = Building(
      id: 'second_landmark',
      name: 'Second Landmark',
      poly: const <Offset>[
        Offset(70, -10),
        Offset(90, -10),
        Offset(90, 10),
        Offset(70, 10),
      ],
      floors: const [],
    );
    final destination = Building(
      id: 'destination',
      name: 'Destination',
      poly: const <Offset>[
        Offset(140, -10),
        Offset(160, -10),
        Offset(160, 10),
        Offset(140, 10),
      ],
      floors: const [],
    );
    final data = CampusData(
      imageSize: const Size(200, 100),
      gates: const [],
      buildings: <Building>[firstLandmark, secondLandmark, destination],
      roads: const RoadGraph(nodes: <String, Offset>{}, edges: []),
    );
    const path = RoutePath(
      points: <Offset>[
        Offset.zero,
        Offset(10, 0),
        Offset(20, 0),
        Offset(30, 0),
        Offset(40, 0),
        Offset(50, 0),
        Offset(60, 0),
        Offset(70, 0),
        Offset(80, 0),
        Offset(90, 0),
        Offset(100, 0),
        Offset(110, 0),
        Offset(120, 0),
      ],
      pixels: 120,
    );

    final steps = const StepsBuilder().build(
      path: path,
      destination: destination,
      room: null,
      startLabel: 'First Gate',
      data: data,
      maxSteps: 10,
    );

    expect(steps, hasLength(3));
    expect(steps[0], 'Head east from First Gate toward the First Landmark.');
    expect(
      steps[1],
      'From the First Landmark, continue east toward the Second Landmark.',
    );
    expect(steps.join(' '), isNot(contains('turn left')));
    expect(steps.join(' '), isNot(contains('turn right')));
  });
}
