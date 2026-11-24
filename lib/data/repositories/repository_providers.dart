import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../services/sync/schedule_sync.dart';
import '../models/campus_data.dart';
import '../models/scheduled_class.dart';
import 'room_details_repository.dart';
import 'saved_buildings_store.dart';
import 'schedule_store.dart';
import 'search_history_store.dart';

/// Overridden in `main()` with the data parsed once at start-up.
final campusDataProvider = Provider<CampusData>(
  (ref) => throw UnimplementedError('campusDataProvider must be overridden'),
);

/// Overridden in `main()` with the optional room details layer.
final roomDetailsProvider = Provider<Map<String, RoomDetails>>(
  (ref) => const <String, RoomDetails>{},
);

final roomDetailsRepositoryProvider = Provider<RoomDetailsRepository>(
  (ref) => const RoomDetailsRepository(),
);

/// Overridden in `main()` with the opened Hive box.
final storageBoxProvider = Provider<Box<String>>(
  (ref) => throw UnimplementedError('storageBoxProvider must be overridden'),
);

final scheduleStoreProvider = Provider<ScheduleStore>(
  (ref) => ScheduleStore(ref.watch(storageBoxProvider)),
);

final searchHistoryStoreProvider = Provider<SearchHistoryStore>(
  (ref) => SearchHistoryStore(ref.watch(storageBoxProvider)),
);

final savedBuildingsStoreProvider = Provider<SavedBuildingsStore>(
  (ref) => SavedBuildingsStore(ref.watch(storageBoxProvider)),
);

final scheduleProvider =
    NotifierProvider<ScheduleController, List<ScheduledClass>>(
      ScheduleController.new,
    );

/// Owns the saved schedule and keeps Hive in sync with the UI.
///
/// While a student is signed in, every change is mirrored to Firestore
/// best-effort (see [ScheduleSyncService]) — Hive remains what the UI reads.
class ScheduleController extends Notifier<List<ScheduledClass>> {
  @override
  List<ScheduledClass> build() => ref.watch(scheduleStoreProvider).read();

  Future<void> replaceAll(List<ScheduledClass> classes) async {
    await ref.read(scheduleStoreProvider).write(classes);
    state = List<ScheduledClass>.unmodifiable(classes);
    unawaited(ref.read(scheduleSyncProvider).push(classes));
  }

  /// Reconciles with the account's remote schedule after sign-in.
  ///
  /// Full-replace semantics: a non-empty remote wins (it was the last
  /// write from any device); a signed-in account with an empty remote
  /// adopts the local schedule instead, so a guest's work is uploaded.
  /// Offline this does nothing — the local schedule is untouched.
  Future<void> syncWithRemote() async {
    final remote = await ref.read(scheduleSyncProvider).pull();
    if (remote == null) {
      return;
    }
    if (remote.isNotEmpty) {
      await replaceAll(remote);
    } else if (state.isNotEmpty) {
      await ref.read(scheduleSyncProvider).push(state);
    }
  }

  Future<void> upsert(ScheduledClass item) async {
    final next = [...state];
    final index = next.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    await replaceAll(next);
  }

  Future<void> remove(String id) async {
    final next = state.where((entry) => entry.id != id).toList();
    await replaceAll(next);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<String>>(
      SearchHistoryController.new,
    );

/// Owns recent searches.
class SearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(searchHistoryStoreProvider).read();

  Future<void> remember(String term) async {
    state = await ref.read(searchHistoryStoreProvider).add(term);
  }

  Future<void> clear() async {
    await ref.read(searchHistoryStoreProvider).clear();
    state = const <String>[];
  }
}

final savedBuildingsProvider =
    NotifierProvider<SavedBuildingsController, List<String>>(
      SavedBuildingsController.new,
    );

/// Owns the bookmarked building ids (most recent first).
class SavedBuildingsController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(savedBuildingsStoreProvider).read();

  Future<void> toggle(String buildingId) async {
    state = await ref.read(savedBuildingsStoreProvider).toggle(buildingId);
  }
}
