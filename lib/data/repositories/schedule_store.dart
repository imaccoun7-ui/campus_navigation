import 'package:hive/hive.dart';

import '../models/scheduled_class.dart';

/// Local, offline persistence for the saved schedule.
///
/// The schedule is stored as one JSON string in the `campus_nav` Hive box, so a
/// restore never needs a migration.
class ScheduleStore {
  ScheduleStore(this._box);

  static const String key = 'schedule';

  final Box<String> _box;

  List<ScheduledClass> read() {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) {
      return const <ScheduledClass>[];
    }
    try {
      return ScheduledClass.decodeList(raw);
    } on FormatException {
      return const <ScheduledClass>[];
    }
  }

  Future<void> write(List<ScheduledClass> classes) =>
      _box.put(key, ScheduledClass.encodeList(classes));
}
