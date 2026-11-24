import 'floor.dart';

/// A single room inside a building, identified by its plain string name from
/// `buildings.json` (for example `T-201 - AutoCAD Lab`).
///
/// Type, capacity and accessibility are **not** stored here: they live in the
/// editable `assets/data/room_details.json` layer.
class Room {
  const Room({
    required this.name,
    required this.buildingId,
    required this.floorLabel,
    required this.indexInBuilding,
  });

  /// Room string exactly as it appears in `buildings.json`.
  final String name;

  final String buildingId;

  /// Label of the floor that lists this room (for example `2nd floor`).
  final String floorLabel;

  /// Position of this room in the building's flattened room list, used by routes.
  final int indexInBuilding;

  static final RegExp _codePattern = RegExp(
    r'\b([A-Z]{1,4})[-\s]?(\d{3})\b',
    caseSensitive: false,
  );

  /// The room code when the name contains one (`T-201 - AutoCAD Lab` -> `T-201`).
  String? get code {
    final match = _codePattern.firstMatch(name.toUpperCase());
    if (match == null) {
      return null;
    }
    return '${match.group(1)}-${match.group(2)}';
  }

  /// True when the name says it is an office.
  bool get looksLikeOffice {
    final lower = name.toLowerCase();
    return lower.contains('office') ||
        lower.contains('registrar') ||
        lower.contains('cashier') ||
        lower.contains('dean') ||
        lower.contains('counter') ||
        lower.contains('faculty');
  }

  /// True when the name says it is a classroom or laboratory.
  bool get looksLikeRoom {
    final lower = name.toLowerCase();
    return code != null ||
        lower.contains('classroom') ||
        lower.contains('laboratory') ||
        lower.contains('lab') ||
        lower.contains('room') ||
        lower.contains('amphitheater') ||
        lower.contains('nook');
  }

  /// Compare-friendly form used for fuzzy OCR matching.
  String get matchKey => Floor.normalizeRoomKey(name);

  @override
  String toString() => '$name ($buildingId, $floorLabel)';
}
