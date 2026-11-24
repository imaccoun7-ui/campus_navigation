import 'package:hive/hive.dart';

/// Local persistence for buildings bookmarked from the map's building sheet.
///
/// Building ids are stored most-recent-first, `\u0001`-joined, matching the
/// [SearchHistoryStore] convention for the shared string box.
class SavedBuildingsStore {
  SavedBuildingsStore(this._box);

  static const String key = 'saved_buildings';

  final Box<String> _box;

  List<String> read() {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    return raw
        .split('\u0001')
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
  }

  /// Adds [buildingId] if absent, removes it if present, persists, and returns
  /// the resulting list.
  Future<List<String>> toggle(String buildingId) async {
    final current = read().toList();
    final removed = current.remove(buildingId);
    if (!removed) {
      current.insert(0, buildingId);
    }
    if (current.isEmpty) {
      await _box.delete(key);
    } else {
      await _box.put(key, current.join('\u0001'));
    }
    return List<String>.unmodifiable(current);
  }
}
