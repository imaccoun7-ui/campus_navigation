import 'dart:math' as math;
import 'dart:ui';

import '../../core/config/app_config.dart';
import '../../data/models/building.dart';
import '../../data/models/campus_data.dart';
import '../../data/models/room.dart';
import 'pathfinder.dart';

/// Turns a route's point list into landmark-based walking instructions.
class StepsBuilder {
  const StepsBuilder();

  List<String> build({
    required RoutePath path,
    required Building destination,
    required Room? room,
    required String startLabel,
    required CampusData data,
    int maxSteps = 6,
  }) {
    final points = _samplePath(path.points);
    final allLandmarks = _landmarksAlongPath(
      points,
      data,
      destination,
      startLabel,
    );
    final availableLandmarks = maxSteps - (room == null ? 2 : 4);
    final landmarkLimit = availableLandmarks > 0 ? availableLandmarks : 0;
    final landmarks = _selectLandmarks(allLandmarks, landmarkLimit);
    final steps = <String>[];

    if (points.length >= 2) {
      final firstLandmark = landmarks.isEmpty ? null : landmarks.first;
      final heading = _compass(
        (firstLandmark?.point ?? points.last) - points.first,
      );
      steps.add(
        firstLandmark == null
            ? 'Head $heading from $startLabel along the campus path.'
            : 'Head $heading from $startLabel toward the ${firstLandmark.building.name}.',
      );
    } else {
      steps.add('Start at $startLabel.');
    }

    for (var index = 1; index < landmarks.length; index++) {
      final previous = landmarks[index - 1];
      final landmark = landmarks[index];
      final heading = _compass(landmark.point - previous.point);
      steps.add(
        'From the ${previous.building.name}, continue $heading toward the ${landmark.building.name}.',
      );
    }

    steps.add('Continue to the entrance of the ${destination.name}.');

    if (room != null) {
      steps.add('Enter and go up to the ${room.floorLabel.toLowerCase()}.');
      steps.add('${room.name} is inside.');
    }

    if (steps.length > maxSteps) {
      return steps.sublist(0, maxSteps - 1)
        ..add('Arrive at ${room?.name ?? destination.name}.');
    }
    return steps;
  }

  List<Offset> _samplePath(List<Offset> path) {
    if (path.length < 2) {
      return path;
    }

    final samples = <Offset>[path.first];
    for (var index = 1; index < path.length; index++) {
      final start = path[index - 1];
      final end = path[index];
      final distance = (end - start).distance;
      if (distance < 0.01) {
        continue;
      }
      final segments = math.max(
        1,
        (distance / AppConfig.roadDensifySpacing).ceil(),
      );
      for (var segment = 1; segment <= segments; segment++) {
        samples.add(Offset.lerp(start, end, segment / segments)!);
      }
    }
    return samples;
  }

  List<_RouteLandmark> _landmarksAlongPath(
    List<Offset> points,
    CampusData data,
    Building destination,
    String startLabel,
  ) {
    if (points.isEmpty) {
      return const <_RouteLandmark>[];
    }

    final excludedIds = <String>{destination.id};
    final startBuildingId = AppConfig.landmarkStartBuildings[startLabel];
    if (startBuildingId != null) {
      excludedIds.add(startBuildingId);
    }
    for (final building in data.buildings) {
      if (building.contains(points.first)) {
        excludedIds.add(building.id);
      }
    }
    final landmarks = <_RouteLandmark>[];
    final seenIds = <String>{};
    Building? currentBuilding;
    var currentCount = 0;
    var closestDistance = double.infinity;
    var closestPoint = Offset.zero;

    void finishLandmarkRun() {
      final building = currentBuilding;
      if (building != null &&
          (currentCount >= 2 || closestDistance <= 35) &&
          seenIds.add(building.id)) {
        landmarks.add(
          _RouteLandmark(building: building, point: closestPoint),
        );
      }
      currentBuilding = null;
      currentCount = 0;
      closestDistance = double.infinity;
    }

    for (final point in points) {
      final closest = _nearestBuilding(
        point,
        data.buildings,
        excludedIds,
      );
      if (closest?.building.id != currentBuilding?.id) {
        finishLandmarkRun();
        if (closest != null) {
          currentBuilding = closest.building;
          closestDistance = closest.distance;
          closestPoint = point;
          currentCount = 1;
        }
      } else if (closest != null) {
        currentCount++;
        if (closest.distance < closestDistance) {
          closestDistance = closest.distance;
          closestPoint = point;
        }
      }
    }
    finishLandmarkRun();
    return landmarks;
  }

  _NearestBuilding? _nearestBuilding(
    Offset point,
    List<Building> buildings,
    Set<String> excludedIds,
  ) {
    Building? closest;
    var bestDistance = AppConfig.landmarkSearchRadius;
    for (final building in buildings) {
      if (excludedIds.contains(building.id)) {
        continue;
      }
      final distance = _distanceToBuilding(point, building);
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = building;
      }
    }
    return closest == null
        ? null
        : _NearestBuilding(building: closest, distance: bestDistance);
  }

  double _distanceToBuilding(Offset point, Building building) {
    if (building.contains(point)) {
      return 0;
    }
    var closestDistance = double.infinity;
    for (var index = 0; index < building.poly.length; index++) {
      final start = building.poly[index];
      final end = building.poly[(index + 1) % building.poly.length];
      final segment = end - start;
      final lengthSquared =
          segment.dx * segment.dx + segment.dy * segment.dy;
      if (lengthSquared < 0.01) {
        continue;
      }
      final projection = point - start;
      final ratio = ((projection.dx * segment.dx +
                  projection.dy * segment.dy) /
              lengthSquared)
          .clamp(0.0, 1.0)
          .toDouble();
      final nearestPoint = Offset(
        start.dx + segment.dx * ratio,
        start.dy + segment.dy * ratio,
      );
      closestDistance = math.min(
        closestDistance,
        (point - nearestPoint).distance,
      );
    }
    return closestDistance;
  }

  List<_RouteLandmark> _selectLandmarks(
    List<_RouteLandmark> landmarks,
    int limit,
  ) {
    if (landmarks.length <= limit) {
      return landmarks;
    }
    if (limit <= 0) {
      return const <_RouteLandmark>[];
    }
    if (limit == 1) {
      return <_RouteLandmark>[landmarks.first];
    }
    return <_RouteLandmark>[
      for (var index = 0; index < limit; index++)
        landmarks[(index * (landmarks.length - 1) / (limit - 1)).round()],
    ];
  }

  String _compass(Offset delta) {
    if (delta.distance < 0.01) {
      return 'forward';
    }
    final degrees =
        (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
    if (degrees >= 315 || degrees < 45) {
      return 'east';
    }
    if (degrees < 135) {
      return 'south';
    }
    if (degrees < 225) {
      return 'west';
    }
    return 'north';
  }

}

class _RouteLandmark {
  const _RouteLandmark({required this.building, required this.point});

  final Building building;
  final Offset point;
}

class _NearestBuilding {
  const _NearestBuilding({required this.building, required this.distance});

  final Building building;
  final double distance;
}
