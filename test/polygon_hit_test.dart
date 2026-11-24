import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/data/models/building.dart';
import 'package:campus_nav/data/models/campus_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CampusData data;

  setUpAll(() {
    final raw = File('assets/data/buildings.json').readAsStringSync();
    data = CampusData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  /// Finds any point that really is inside a (possibly concave) outline.
  Offset? interiorPoint(Building building) {
    final bounds = building.bounds;
    for (var dx = 0.1; dx < 1; dx += 0.1) {
      for (var dy = 0.1; dy < 1; dy += 0.1) {
        final point = Offset(
          bounds.left + bounds.width * dx,
          bounds.top + bounds.height * dy,
        );
        if (building.contains(point)) {
          return point;
        }
      }
    }
    return null;
  }

  test('a tap inside a building outline hits that building', () {
    for (final building in data.buildings) {
      expect(
        interiorPoint(building),
        isNotNull,
        reason: '${building.name} has no tappable interior point',
      );
    }
  });

  test('a tap outside a building outline misses it', () {
    final snhs = data.buildingById('snhs')!;
    expect(snhs.contains(const Offset(700, 950)), isFalse);
    expect(snhs.contains(const Offset(215, 258)), isFalse);
  });

  test('hit testing is in image space, not screen space', () {
    final gym = data.buildingById('gym')!;
    // A pixel coordinate from the 1346x1168 illustration.
    expect(gym.contains(const Offset(410, 360)), isTrue);
    // The same coordinate scaled down for a 390px-wide screen would miss.
    const scaled = Offset(410 * 390 / 1346, 360 * 390 / 1346);
    expect(gym.contains(scaled), isFalse);
  });

  test('the polygon Path is built once and cached', () {
    final sme = data.buildingById('sme')!;
    expect(identical(sme.path, sme.path), isTrue);
    expect(sme.path.getBounds(), sme.bounds);
  });

  test('overlapping buildings resolve to the last painted one', () {
    // Lecture halls on the east side are adjacent; a point in the oval track
    // must not be reported as the Volleyball Court.
    final oval = data.buildingById('oval')!;
    final vball = data.buildingById('vball')!;
    const point = Offset(820, 560);
    expect(oval.contains(point), isTrue);
    expect(vball.contains(point), isFalse);
  });
}
