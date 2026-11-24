import 'dart:ui';

import 'floor.dart';
import 'room.dart';

/// A building on the illustrated campus map.
///
/// [poly] is the tappable outline in **image pixels** of the 1346 x 1168 map, so
/// it never has to be converted when the viewer zooms or pans. The [Path] is
/// built once in the constructor and reused for every hit test and paint.
class Building {
  Building({
    required this.id,
    required this.name,
    required this.poly,
    required this.floors,
  }) : path = _buildPath(poly);

  factory Building.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    final points = (json['poly'] as List<dynamic>)
        .map(
          (point) => Offset(
            ((point as List<dynamic>)[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ),
        )
        .toList(growable: false);
    final floorJson = json['floors'] as List<dynamic>? ?? const <dynamic>[];
    final floors = <Floor>[];
    var roomIndex = 0;
    for (final entry in floorJson) {
      final floor = Floor.fromJson(
        entry as Map<String, dynamic>,
        id,
        roomIndex,
      );
      roomIndex += floor.rooms.length;
      floors.add(floor);
    }
    return Building(id: id, name: name, poly: points, floors: floors);
  }

  final String id;
  final String name;
  final List<Offset> poly;
  final List<Floor> floors;

  /// Cached outline, built once so hit testing never rebuilds a [Path].
  final Path path;

  Rect get bounds => path.getBounds();

  Offset get centroid => bounds.center;

  /// True when no room data exists for this building yet.
  bool get hasRoomData => floors.isNotEmpty && rooms.isNotEmpty;

  List<Room> get rooms =>
      floors.expand((floor) => floor.rooms).toList(growable: false);

  int get roomCount => floors.fold(0, (sum, floor) => sum + floor.rooms.length);

  /// Image-space hit test against the building outline.
  bool contains(Offset imagePoint) => path.contains(imagePoint);

  Room? roomByIndex(int index) {
    for (final floor in floors) {
      for (final room in floor.rooms) {
        if (room.indexInBuilding == index) {
          return room;
        }
      }
    }
    return null;
  }

  Room? roomNamed(String? name) {
    if (name == null) {
      return null;
    }
    for (final room in rooms) {
      if (room.name == name) {
        return room;
      }
    }
    return null;
  }

  static Path _buildPath(List<Offset> poly) {
    final path = Path();
    if (poly.isEmpty) {
      return path;
    }
    path.moveTo(poly.first.dx, poly.first.dy);
    for (final point in poly.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }
}
