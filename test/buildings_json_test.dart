import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:campus_nav/data/models/campus_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CampusData data;

  setUpAll(() {
    final raw = File('assets/data/buildings.json').readAsStringSync();
    data = CampusData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('image size matches the illustration', () {
    expect(data.imageSize, const Size(1346, 1168));
  });

  test('every building in the file is parsed with an outline', () {
    expect(data.buildings.length, 18);
    for (final building in data.buildings) {
      expect(
        building.poly.length,
        greaterThanOrEqualTo(3),
        reason: building.id,
      );
      expect(building.bounds.width, greaterThan(0), reason: building.id);
      expect(building.bounds.height, greaterThan(0), reason: building.id);
    }
  });

  test('building ids are unique', () {
    final ids = data.buildings.map((building) => building.id).toSet();
    expect(ids.length, data.buildings.length);
  });

  test('both gates are loaded', () {
    expect(data.gates.map((gate) => gate.name), contains('First Gate'));
    expect(data.gates.map((gate) => gate.name), contains('Second Gate'));
    expect(data.gateByName('First Gate')!.position, const Offset(215, 258));
  });

  test('rooms are plain strings attached to their floor', () {
    final snhs = data.buildingById('snhs')!;
    expect(snhs.floors.first.label, '1st floor');
    expect(snhs.floors.first.rooms.first.name, 'Accounting Office');
    expect(snhs.floors.first.rooms.first.floorLabel, '1st floor');
    expect(snhs.roomCount, 15);
    expect(
      snhs.rooms.map((room) => room.indexInBuilding),
      everyElement(isNonNegative),
    );
  });

  test('room codes are recognised from plain room strings', () {
    final stcs = data.buildingById('stcs')!;
    final autocad = stcs.roomNamed('T-201 - AutoCAD Lab')!;
    expect(autocad.code, 'T-201');
    expect(autocad.floorLabel, '2nd floor');
    final andaya = data.buildingById('andaya')!;
    expect(andaya.roomNamed('AH201')!.code, 'AH-201');
  });

  test('buildings without room data are kept and marked', () {
    final without = data.buildingsWithoutRoomData;
    expect(without.length, 6);
    expect(
      without.map((building) => building.id),
      containsAll(<String>['student', 'eng', 'tennis']),
    );
    expect(without.every((building) => !building.hasRoomData), isTrue);
  });

  test('road graph is loaded with nodes and edges', () {
    expect(data.roads.nodes.length, greaterThan(20));
    expect(data.roads.edges, isNotEmpty);
    expect(data.roads.nodes.containsKey('G1'), isTrue);
    expect(data.roads.nodes.containsKey('G2'), isTrue);
    for (final edge in data.roads.edges) {
      expect(data.roads.nodes.containsKey(edge.a), isTrue, reason: edge.a);
      expect(data.roads.nodes.containsKey(edge.b), isTrue, reason: edge.b);
    }
  });

  test('search finds rooms and buildings', () {
    expect(data.search('autocad'), isNotEmpty);
    expect(data.search('gymnasium').first.building.id, 'gym');
    expect(data.search('  '), isEmpty);
  });
}
