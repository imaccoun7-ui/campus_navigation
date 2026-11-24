import 'dart:math' as math;

import '../../data/models/building.dart';
import '../../data/models/campus_data.dart';
import '../../data/models/floor.dart';
import '../../data/models/room.dart';

/// A resolved room and the confidence the matcher had in it.
class RoomMatch {
  const RoomMatch({
    required this.building,
    required this.room,
    required this.confidence,
  });

  final Building building;
  final Room room;

  /// 1.0 for an exact code match, lower for fuzzy matches.
  final double confidence;

  bool get isExact => confidence >= 1;
}

/// Matches scanned room text against the rooms listed in `buildings.json`.
///
/// OCR output is noisy (`O` for `0`, dropped hyphens, extra spaces), so matching
/// runs on a normalised key and falls back to edit distance.
///
/// Study loads often print department abbreviations that differ from the map's
/// room-code prefixes (e.g. `TECH302` vs `T-302`, `NURSING302` vs `N-302`).
/// `_departmentAliases` maps study-load prefixes to map prefixes so every
/// department resolves correctly.
class RoomMatcher {
  RoomMatcher(this.data) : _entries = _buildIndex(data);

  final CampusData data;
  final List<_Entry> _entries;

  static List<_Entry> _buildIndex(CampusData data) {
    final entries = <_Entry>[];
    for (final building in data.buildings) {
      for (final room in building.rooms) {
        entries.add(
          _Entry(
            building: building,
            room: room,
            key: Floor.normalizeRoomKey(room.name),
            codeKey: Floor.normalizeRoomKey(room.code ?? ''),
          ),
        );
      }
    }
    return entries;
  }

  /// Study-load department prefixes mapped to the map's room-code prefix.
  ///
  /// Example: `TECH302` (study load) → `T-302` (map data).
  static final Map<String, String> _departmentAliases = <String, String>{
    'TECH': 'T',      // STCS: Technology and Computer Studies
    'NURSING': 'N',   // SNHS: Nursing, Health and Science
    'SNHS': 'N',      // SNHS
    'TED': 'A',       // STE: Teacher Education
    'TEACHERED': 'A', // STE
    'STE': 'A',       // STE
    'AUTO': 'AB',     // Automotive
    'CERAMIC': 'C',   // Old Ceramic
    'MARITIME': 'MB', // Maritime
    'SAS': 'A',       // School of Arts and Sciences
    'SME': 'SME',     // School of Management and Entrepreneurship
  };

  RoomMatch? match(String roomText) {
    final query = Floor.normalizeRoomKey(roomText);
    if (query.length < 2) {
      return null;
    }

    final variants = _queryVariants(roomText, query);

    // 1. Exact room-code match (try every alias variant).
    for (final variant in variants) {
      final codeMatches = _entries
          .where(
            (entry) => entry.codeKey.isNotEmpty && entry.codeKey == variant,
          )
          .toList();
      if (codeMatches.isEmpty) {
        continue;
      }
      // Duplicate map rows for the same code (for example `C-102` listed in
      // both ceramic building records) all point at the same room, so the
      // first one is a safe, deterministic match.
      final names = codeMatches.map((entry) => entry.room.name).toSet();
      if (names.length == 1) {
        return _toMatch(codeMatches.first, 1);
      }
    }

    // Build the search pool using every variant prefix so aliased departments
    // are not excluded (e.g. TECH302 → T302 must still find the T- building).
    final pool = _poolFor(roomText, query, variants);
    if (pool.isEmpty) {
      return null;
    }

    // 2. Exact normalised name match (try every alias variant).
    for (final variant in variants) {
      final nameMatches = pool.where((entry) => entry.key == variant).toList();
      if (nameMatches.length == 1) {
        return _toMatch(nameMatches.first, 1);
      }
    }

    // 3. The scanned text is contained in a room name, or vice versa.
    for (final variant in variants) {
      final contains = pool
          .where(
            (entry) =>
                entry.key.contains(variant) ||
                (entry.key.length >= 4 && variant.contains(entry.key)),
          )
          .toList();
      if (contains.length == 1) {
        return _toMatch(contains.first, 0.85);
      }
    }

    // 4. Nearest by edit distance, ignoring near misses.
    _Entry? best;
    var bestDistance = 3;
    var ambiguous = false;
    for (final entry in pool) {
      final distance = _levenshtein(query, entry.key);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry;
        ambiguous = false;
      } else if (distance == bestDistance && best != null) {
        ambiguous = true;
      }
    }
    if (best == null || ambiguous) {
      return null;
    }
    return _toMatch(best, bestDistance == 1 ? 0.7 : 0.5);
  }

  /// Returns the query plus every department-alias variant, so `TECH302` also
  /// tries `T302`, `NURSING302` also tries `N302`, etc.
  ///
  /// Prefixes are read from the raw text because [Floor.normalizeRoomKey]
  /// replaces letters (`NURSING` -> `NUR51NG`, `SNHS` -> `5NH5`), which would
  /// stop those aliases from ever matching.
  List<String> _queryVariants(String roomText, String query) {
    final variants = <String>{query};
    final plain = roomText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    _departmentAliases.forEach((studyPrefix, mapPrefix) {
      if (!plain.startsWith(studyPrefix)) {
        return;
      }
      final rest = plain.substring(studyPrefix.length);
      variants.add('$mapPrefix${Floor.normalizeRoomKey(rest)}');
    });
    return variants.toList(growable: false);
  }

  /// Rooms with any of the variant prefixes as their leading letters.
  ///
  /// The prefix is taken from the raw text because [Floor.normalizeRoomKey]
  /// deliberately turns `BI` into `81`.
  List<_Entry> _poolFor(
    String roomText,
    String query,
    List<String> variants,
  ) {
    if (!RegExp(r'\d').hasMatch(query)) {
      return _entries;
    }

    final prefixes = <String>{};
    for (final variant in variants) {
      final prefix =
          RegExp(r'^[A-Za-z]+').firstMatch(variant)?.group(0) ?? '';
      if (prefix.isNotEmpty) {
        prefixes.add(prefix.toUpperCase());
      }
    }
    final originalPrefix =
        RegExp(r'^[A-Za-z]+').firstMatch(roomText.trim())?.group(0) ?? '';
    if (originalPrefix.isNotEmpty) {
      prefixes.add(originalPrefix.toUpperCase());
    }
    if (prefixes.isEmpty) {
      return _entries;
    }

    return _entries
        .where(
          (entry) =>
              prefixes.any(
                (p) => entry.codeLetters.startsWith(p) ||
                    entry.key.startsWith(p),
              ),
        )
        .toList(growable: false);
  }

  RoomMatch _toMatch(_Entry entry, double confidence) => RoomMatch(
        building: entry.building,
        room: entry.room,
        confidence: confidence,
      );

  static int _levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    var previous = List<int>.generate(b.length + 1, (index) => index);
    var current = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = math.min(deletion, math.min(insertion, substitution));
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }
}

class _Entry {
  const _Entry({
    required this.building,
    required this.room,
    required this.key,
    required this.codeKey,
  });

  final Building building;
  final Room room;
  final String key;
  final String codeKey;

  /// Letters at the start of the room code, before normalisation (`T`, `BI`).
  String get codeLetters =>
      RegExp(r'^[A-Z]+').firstMatch(room.code?.toUpperCase() ?? '')?.group(0) ??
      '';
}
