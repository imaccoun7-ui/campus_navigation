import 'dart:convert';
import 'dart:io';

import 'package:campus_nav/data/models/campus_data.dart';
import 'package:campus_nav/services/matching/room_matcher.dart';
import 'package:campus_nav/services/ocr/study_load_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Room codes as they are printed on a real study load (`TECH302`) must resolve
/// to the rooms the map data lists (`T-302 - Computer Laboratory`).
void main() {
  late CampusData data;
  late RoomMatcher matcher;

  setUpAll(() {
    final raw = File('assets/data/buildings.json').readAsStringSync();
    data = CampusData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    matcher = RoomMatcher(data);
  });

  test('TECH302 resolves to T-302 in the STCS building', () {
    final match = matcher.match('TECH302');
    expect(match, isNotNull);
    expect(match!.building.id, 'stcs');
    expect(match.room.code, 'T-302');
    expect(match.room.name, 'T-302');
    expect(match.isExact, isTrue);
  });

  test('TECH203 resolves to T-203, not a fuzzy neighbour', () {
    expect(matcher.match('TECH203')!.room.code, 'T-203');
  });

  test('a parsed TECH302 room resolves to T-302', () {
    const parser = StudyLoadParser();
    final parsed = parser
        .parse('C161\tInformation Management\t3-4 pm MTh\tTECH302')
        .first;

    expect(parsed.roomText, 'TECH-302');
    expect(matcher.match(parsed.roomText)!.room.name, 'T-302');
  });

  test('duplicate C-prefix room codes resolve when their names agree', () {
    expect(matcher.match('C-102')!.room.code, 'C-102');
    expect(matcher.match('C-202')!.room.code, 'C-202');
  });

  test('codes that are not on the map do not resolve', () {
    expect(matcher.match('BI1101'), isNull);
  });
}
