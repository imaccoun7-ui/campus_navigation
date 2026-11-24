import 'package:hive/hive.dart';

/// Local persistence for recent search terms and one-off flags.
class SearchHistoryStore {
  SearchHistoryStore(this._box);

  static const String key = 'recent_searches';
  static const int maxEntries = 8;

  final Box<String> _box;

  List<String> read() {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }
    return raw
        .split('\u0001')
        .where((term) => term.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> add(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      return read();
    }
    final current = read().toList()
      ..removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase())
      ..insert(0, trimmed);
    final next = current.take(maxEntries).toList(growable: false);
    await _box.put(key, next.join('\u0001'));
    return next;
  }

  Future<void> clear() => _box.delete(key);
}
