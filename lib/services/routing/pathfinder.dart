import 'dart:math' as math;
import 'dart:ui';

import '../../core/config/app_config.dart';
import '../../data/models/building.dart';
import '../../data/models/campus_data.dart';
import '../../data/models/road_graph.dart';
import 'dijkstra.dart';

/// One link in the densified road network.
class RoutedEdge {
  const RoutedEdge(this.to, this.weight);

  final String to;
  final double weight;
}

/// The road network after densification, with a door node per building.
class RoadNetwork {
  const RoadNetwork({
    required this.nodes,
    required this.adjacency,
    required this.doorNodes,
    required this.roadPoints,
  });

  final Map<String, Offset> nodes;
  final Map<String, List<RoutedEdge>> adjacency;

  /// Building id -> id of the node placed on its door point.
  final Map<String, String> doorNodes;

  /// Every road point, used for snapping and for door detection.
  final List<Offset> roadPoints;
}

/// A computed walking route, in image pixels.
class RoutePath {
  const RoutePath({required this.points, required this.pixels});

  final List<Offset> points;

  /// Total length in image pixels.
  final double pixels;

  double get meters => pixels * AppConfig.metersPerPixel;

  Duration get duration {
    final minutes = meters / AppConfig.walkingMetersPerMinute;
    return Duration(minutes: math.max(1, minutes.round()));
  }

  Rect get bounds {
    if (points.isEmpty) {
      return Rect.zero;
    }
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in points) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// Turns the image-derived campus road centerlines in `buildings.json` into a
/// routable graph, excluding Naval Road, then runs Dijkstra over it.
///
/// Built lazily, once per instance:
/// 1. every edge is densified into points about [spacing] pixels apart,
/// 2. each building gets a door point whose connector does not cross a building,
/// 3. that door is linked to the nearest safe road point.
class Pathfinder {
  Pathfinder(this.data, {this.spacing = AppConfig.roadDensifySpacing});

  final CampusData data;
  final double spacing;

  late final RoadNetwork network = _buildNetwork();

  RoutePath? findRoute({
    required String fromNodeId,
    required String toBuildingId,
  }) {
    final goal = network.doorNodes[toBuildingId];
    if (goal == null) {
      return null;
    }
    final ids = Dijkstra.shortestPath(
      start: fromNodeId,
      goal: goal,
      neighbours: (node) => (network.adjacency[node] ?? const <RoutedEdge>[])
          .map((edge) => (to: edge.to, weight: edge.weight)),
    );
    if (ids == null) {
      return null;
    }
    final points = <Offset>[];
    for (final id in ids) {
      final point = network.nodes[id];
      if (point == null) {
        continue;
      }
      if (points.isEmpty || (points.last - point).distance > 0.01) {
        points.add(point);
      }
    }
    return RoutePath(points: points, pixels: _length(points));
  }

  /// Route from an arbitrary image point (a dropped pin) to a building.
  RoutePath? findRouteFromPoint({
    required Offset point,
    required String toBuildingId,
  }) {
    return findRoute(
      fromNodeId: nearestRoadNodeId(point),
      toBuildingId: toBuildingId,
    );
  }

  /// Nearest node of the densified network to [point].
  String nearestNodeId(Offset point) {
    var bestId = network.nodes.keys.first;
    var bestDistance = double.infinity;
    network.nodes.forEach((id, candidate) {
      final distance = (candidate - point).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestId = id;
      }
    });
    return bestId;
  }

  /// Nearest **road-graph** node to [point]. Only searches the original traced
  /// road nodes (`data.roads.nodes`), excluding Naval Road, door nodes, and
  /// densified edge points, so snapped start points sit on a campus road.
  String nearestRoadNodeId(Offset point) {
    if (data.roads.nodes.isEmpty) {
      return nearestNodeId(point);
    }
    String? bestId;
    var bestDistance = double.infinity;
    data.roads.nodes.forEach((id, candidate) {
      if (!network.adjacency.containsKey(id)) {
        return;
      }
      final distance = (candidate - point).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestId = id;
      }
    });
    return bestId ?? nearestNodeId(point);
  }

  /// Snaps a dropped pin onto the road network.
  Offset snapToRoad(Offset point) {
    var best = network.nodes.values.isEmpty
        ? point
        : network.nodes.values.first;
    var bestDistance = double.infinity;
    for (final entry in network.nodes.entries) {
      if (entry.key.startsWith('door_')) {
        continue;
      }
      final distance = (entry.value - point).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry.value;
      }
    }
    return best;
  }

  /// The node used when a route starts at a gate.
  String gateNodeId(String gateName) {
    final gate = data.gateByName(gateName);
    if (gate == null) {
      return nearestRoadNodeId(Offset.zero);
    }
    return nearestRoadNodeId(gate.position);
  }

  /// The node used when a route starts inside a building.
  String? buildingNodeId(String buildingId) => network.doorNodes[buildingId];

  RoadNetwork _buildNetwork() {
    final nodes = <String, Offset>{};
    final adjacency = <String, List<RoutedEdge>>{};

    void link(String a, String b, double weight) {
      adjacency.putIfAbsent(a, () => <RoutedEdge>[]).add(RoutedEdge(b, weight));
      adjacency.putIfAbsent(b, () => <RoutedEdge>[]).add(RoutedEdge(a, weight));
    }

    var edgeIndex = 0;
    for (final RoadEdge edge in data.roads.edges) {
      final start = data.roads.nodes[edge.a];
      final end = data.roads.nodes[edge.b];
      if (start == null || end == null) {
        continue;
      }
      final length = (end - start).distance;
      if (length <= 0.01) {
        continue;
      }
      if (_segmentCrossesNavalRoad(start, end)) {
        continue;
      }
      nodes[edge.a] = start;
      nodes[edge.b] = end;
      final steps = math.max(1, (length / spacing).ceil());
      var previousId = edge.a;
      var previousPoint = start;
      for (var step = 1; step <= steps; step++) {
        final ratio = step / steps;
        final point = Offset.lerp(start, end, ratio)!;
        final id = step == steps ? edge.b : 'e${edgeIndex}_$step';
        if (step != steps) {
          nodes[id] = point;
        }
        final weight = (point - previousPoint).distance;
        if (weight > 0.01) {
          link(previousId, id, weight);
        }
        previousId = id;
        previousPoint = point;
      }
      edgeIndex++;
    }

    final roadEntries = <({String id, Offset point})>[
      for (final entry in nodes.entries) (id: entry.key, point: entry.value),
    ];
    final doorNodes = <String, String>{};

    for (final building in data.buildings) {
      final door = _findDoor(building, roadEntries);
      if (door == null) {
        continue;
      }
      final doorId = 'door_${building.id}';
      nodes[doorId] = door.point;
      link(doorId, door.roadNodeId, door.distanceToRoad);
      doorNodes[building.id] = doorId;
    }

    return RoadNetwork(
      nodes: nodes,
      adjacency: adjacency,
      doorNodes: doorNodes,
      roadPoints: nodes.values.toList(growable: false),
    );
  }

  /// Finds a boundary point and nearby road node whose connector clears all
  /// building interiors.
  _DoorPoint? _findDoor(
    Building building,
    List<({String id, Offset point})> roads,
  ) {
    final poly = building.poly;
    if (poly.length < 3 || roads.isEmpty) {
      return null;
    }
    Offset? bestDoor;
    String? bestNodeId;
    var bestDistance = double.infinity;

    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final length = (b - a).distance;
      if (length <= 0.01) {
        continue;
      }
      final samples = math.max(2, (length / 8).ceil());
      for (var s = 0; s <= samples; s++) {
        final point = Offset.lerp(a, b, s / samples)!;
        for (final road in roads) {
          final distance = (road.point - point).distance;
          if (distance < bestDistance &&
              !_connectorCrossesBuilding(point, road.point)) {
            bestDistance = distance;
            bestDoor = point;
            bestNodeId = road.id;
          }
        }
      }
    }

    if (bestDoor == null || bestNodeId == null) {
      return null;
    }
    return _DoorPoint(
      point: bestDoor,
      roadNodeId: bestNodeId,
      distanceToRoad: bestDistance,
    );
  }

  bool _connectorCrossesBuilding(Offset start, Offset end) {
    final steps = math.max(2, ((end - start).distance / 4).ceil());
    for (var step = 1; step < steps; step++) {
      final point = Offset.lerp(start, end, step / steps)!;
      if (data.buildings.any((building) => building.contains(point))) {
        return true;
      }
    }
    return false;
  }

  bool _segmentCrossesNavalRoad(Offset start, Offset end) {
    final steps = math.max(1, ((end - start).distance / 4).ceil());
    for (var step = 0; step <= steps; step++) {
      final point = Offset.lerp(start, end, step / steps)!;
      if (_isOnNavalRoad(point)) {
        return true;
      }
    }
    return false;
  }

  bool _isOnNavalRoad(Offset point) {
    if (point.dx < 0 || point.dx > 1185) {
      return false;
    }
    final campusEdgeY = 322 - 0.211 * point.dx;
    return point.dy < campusEdgeY;
  }

  static double _length(List<Offset> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }
}

class _DoorPoint {
  const _DoorPoint({
    required this.point,
    required this.roadNodeId,
    required this.distanceToRoad,
  });

  final Offset point;
  final String roadNodeId;
  final double distanceToRoad;
}
