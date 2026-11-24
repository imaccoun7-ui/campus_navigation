import 'dart:ui';

import 'building.dart';
import 'floor.dart';
import 'gate.dart';
import 'road_graph.dart';
import 'room.dart';

/// Everything the app knows about the campus, loaded once at start-up.
class CampusData {
  const CampusData({
    required this.imageSize,
    required this.gates,
    required this.buildings,
    required this.roads,
  });

  factory CampusData.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as Map<String, dynamic>? ?? const {};
    final gates = (json['gates'] as List<dynamic>? ?? const <dynamic>[])
        .map((gate) => Gate.fromJson(gate as Map<String, dynamic>))
        .toList(growable: false);
    final buildings = (json['buildings'] as List<dynamic>? ?? const <dynamic>[])
        .map((building) => Building.fromJson(building as Map<String, dynamic>))
        .toList(growable: false);
    final roads = RoadGraph.fromJson(
      json['roads'] as Map<String, dynamic>? ?? const {},
    );
    return CampusData(
      imageSize: Size(
        ((image['width'] as num?) ?? 1346).toDouble(),
        ((image['height'] as num?) ?? 1168).toDouble(),
      ),
      gates: gates,
      buildings: buildings,
      roads: roads,
    );
  }

  /// Pixel size of the campus illustration.
  final Size imageSize;

  final List<Gate> gates;
  final List<Building> buildings;
  final RoadGraph roads;

  Building? buildingById(String? id) {
    if (id == null) {
      return null;
    }
    for (final building in buildings) {
      if (building.id == id) {
        return building;
      }
    }
    return null;
  }

  Gate? gateByName(String name) {
    for (final gate in gates) {
      if (gate.name.toLowerCase() == name.toLowerCase()) {
        return gate;
      }
    }
    return null;
  }

  Room? roomOf(Building building, int? index) =>
      index == null ? null : building.roomByIndex(index);

  /// Every room in the campus, paired with its building.
  List<({Building building, Room room})> get allRooms {
    final result = <({Building building, Room room})>[];
    for (final building in buildings) {
      for (final room in building.rooms) {
        result.add((building: building, room: room));
      }
    }
    return result;
  }

  /// Rooms plus buildings whose name matches [query] loosely.
  List<SearchHit> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <SearchHit>[];
    }
    final needle = trimmed.toLowerCase();
    final hits = <SearchHit>[];
    for (final building in buildings) {
      if (building.name.toLowerCase().contains(needle)) {
        hits.add(SearchHit.building(building));
      }
      for (final floor in building.floors) {
        for (final room in floor.rooms) {
          if (room.name.toLowerCase().contains(needle)) {
            hits.add(SearchHit.room(building, room));
          }
        }
      }
    }
    return hits;
  }

  /// Buildings that currently have no room data, for the "No room details yet"
  /// browse state.
  List<Building> get buildingsWithoutRoomData =>
      buildings.where((building) => !building.hasRoomData).toList();
}

/// One row in the search results list.
class SearchHit {
  const SearchHit({required this.building, this.room});

  const SearchHit.building(Building building) : this(building: building);

  const SearchHit.room(Building building, Room room)
    : this(building: building, room: room);

  final Building building;
  final Room? room;

  bool get isRoom => room != null;

  String get title => room?.name ?? building.name;

  String get subtitle => room == null
      ? (building.hasRoomData
            ? '${building.roomCount} rooms'
            : 'No room details yet')
      : '${building.name} > ${room!.floorLabel}';
}

/// Normalises a room string for fuzzy comparison; re-exported for convenience.
String normalizeRoomKey(String value) => Floor.normalizeRoomKey(value);
