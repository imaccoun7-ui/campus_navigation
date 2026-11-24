import 'room.dart';

/// One floor (or side) of a building, holding the plain room strings listed in
/// `buildings.json`.
class Floor {
  const Floor({required this.label, required this.rooms});

  factory Floor.fromJson(
    Map<String, dynamic> json,
    String buildingId,
    int startIndex,
  ) {
    final label = json['label'] as String? ?? 'Floor';
    final names = (json['rooms'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
    final rooms = <Room>[
      for (var i = 0; i < names.length; i++)
        Room(
          name: names[i],
          buildingId: buildingId,
          floorLabel: label,
          indexInBuilding: startIndex + i,
        ),
    ];
    return Floor(label: label, rooms: rooms);
  }

  final String label;
  final List<Room> rooms;

  /// Numeric floor parsed from the label when one is present.
  ///
  /// `1st floor` -> 1, `2nd floor, right side` -> 2, `Behind the hostel` -> null.
  int? get number {
    final match = RegExp(
      r'(\d+)\s*(?:st|nd|rd|th)',
      caseSensitive: false,
    ).firstMatch(label);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Turns a room string into a comparison key that tolerates common OCR slips
  /// (`O` for `0`, missing hyphens, stray spaces).
  static String normalizeRoomKey(String value) {
    final upper = value.toUpperCase();
    final buffer = StringBuffer();
    for (final rune in upper.runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case 'O':
          buffer.write('0');
        case 'I':
        case 'L':
          buffer.write('1');
        case 'S':
          buffer.write('5');
        case 'B':
          buffer.write('8');
        case ' ':
        case '-':
        case '_':
        case '.':
        case '/':
          continue;
        default:
          if (RegExp(r'[A-Z0-9]').hasMatch(char)) {
            buffer.write(char);
          }
      }
    }
    return buffer.toString();
  }
}
