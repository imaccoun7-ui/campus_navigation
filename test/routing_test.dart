import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/data/models/campus_data.dart';
import 'package:campus_nav/services/routing/pathfinder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CampusData data;
  late Pathfinder pathfinder;

  setUpAll(() {
    final raw = File('assets/data/buildings.json').readAsStringSync();
    data = CampusData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    pathfinder = Pathfinder(data);
  });

  test('every building gets a door node on the road network', () {
    for (final building in data.buildings) {
      expect(
        pathfinder.network.doorNodes.containsKey(building.id),
        isTrue,
        reason: '${building.name} has no door point',
      );
    }
  });

  test('edges are densified to roughly 20 px', () {
    expect(
      pathfinder.network.nodes.keys.any((id) => id.startsWith('e')),
      isTrue,
    );
    pathfinder.network.adjacency.forEach((node, neighbours) {
      if (node.startsWith('door_')) {
        return;
      }
      for (final edge in neighbours) {
        // Door links are a single jump from the building outline to a road
        // point, so they are longer than the densified 20 px spacing.
        if (edge.to.startsWith('door_')) {
          continue;
        }
        expect(edge.weight, lessThanOrEqualTo(21), reason: node);
      }
    });
  });

  test('every building is reachable from the First Gate', () {
    final start = pathfinder.gateNodeId('First Gate');
    for (final building in data.buildings) {
      final route = pathfinder.findRoute(
        fromNodeId: start,
        toBuildingId: building.id,
      );
      expect(route, isNotNull, reason: '${building.name} is unreachable');
      expect(route!.points.length, greaterThan(1), reason: building.name);
      expect(route.pixels, greaterThan(0), reason: building.name);
    }
  });

  test('every building is reachable from the Second Gate', () {
    final start = pathfinder.gateNodeId('Second Gate');
    for (final building in data.buildings) {
      expect(
        pathfinder.findRoute(fromNodeId: start, toBuildingId: building.id),
        isNotNull,
        reason: '${building.name} is unreachable from the Second Gate',
      );
    }
  });

  test('First Gate to Andaya uses the short internal road connection', () {
    final route = pathfinder.findRoute(
      fromNodeId: pathfinder.gateNodeId('First Gate'),
      toBuildingId: 'andaya',
    )!;
    expect(route.pixels, lessThan(800));
  });

  test('route segments do not pass through building interiors', () {
    final start = pathfinder.gateNodeId('First Gate');
    for (final building in data.buildings) {
      final route = pathfinder.findRoute(
        fromNodeId: start,
        toBuildingId: building.id,
      )!;
      for (var i = 1; i < route.points.length; i++) {
        final from = route.points[i - 1];
        final to = route.points[i];
        final steps = ((to - from).distance / 4).ceil();
        for (var step = 1; step < steps; step++) {
          final point = Offset.lerp(from, to, step / steps)!;
          expect(
            data.buildings.where((candidate) => candidate.contains(point)),
            isEmpty,
            reason:
                'Route to ${building.name} crosses a building at $point '
                'between $from and $to',
          );
        }
      }
    }
  });

  test('routes and start points stay off Naval Road', () {
    bool isOnNavalRoad(Offset point) {
      if (point.dx < 0 || point.dx > 1185) {
        return false;
      }
      return point.dy < 322 - 0.211 * point.dx;
    }

    for (final gateName in ['First Gate', 'Second Gate']) {
      final start = pathfinder.gateNodeId(gateName);
      expect(
        isOnNavalRoad(pathfinder.network.nodes[start]!),
        isFalse,
        reason: '$gateName should connect to the nearest campus-side path',
      );
      for (final building in data.buildings) {
        final route = pathfinder.findRoute(
          fromNodeId: start,
          toBuildingId: building.id,
        );
        expect(route, isNotNull, reason: '${building.name} is unreachable');
        for (final point in route!.points) {
          expect(
            isOnNavalRoad(point),
            isFalse,
            reason: 'Route to ${building.name} uses Naval Road',
          );
        }
      }
    }
  });

  test('a route is shorter than the crude door-to-door detour', () {
    final start = pathfinder.gateNodeId('First Gate');
    final route = pathfinder.findRoute(
      fromNodeId: start,
      toBuildingId: 'stcs',
    )!;
    final door =
        pathfinder.network.nodes[pathfinder.network.doorNodes['stcs']]!;
    final gate = pathfinder.network.nodes[start]!;
    expect(route.pixels, lessThanOrEqualTo((door - gate).distance * 4));
  });

  test('a dropped pin snaps to the road network', () {
    const pin = Offset(500, 500);
    final snapped = pathfinder.snapToRoad(pin);
    expect((snapped - pin).distance, lessThan(120));
  });

  test('a pin on Naval Road snaps to the nearest campus road', () {
    const pin = Offset(600, 100);
    final snapped = pathfinder.snapToRoad(pin);
    expect(snapped.dy, greaterThanOrEqualTo(322 - 0.211 * snapped.dx));
  });

  test('distance and time derive from the one config constant', () {
    final route = pathfinder.findRoute(
      fromNodeId: pathfinder.gateNodeId('First Gate'),
      toBuildingId: 'sme',
    )!;
    expect(route.meters, greaterThan(0));
    expect(route.duration.inMinutes, greaterThanOrEqualTo(1));
  });
}
