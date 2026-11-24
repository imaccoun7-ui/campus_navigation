import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ocr/study_load_scanner.dart';
import '../review/draft_class.dart';

/// The file waiting to be scanned, set by the Upload screen.
final pendingScanFileProvider =
    NotifierProvider<PendingScanFileController, StudyLoadFile?>(
      PendingScanFileController.new,
    );

class PendingScanFileController extends Notifier<StudyLoadFile?> {
  @override
  StudyLoadFile? build() => null;

  void set(StudyLoadFile? file) => state = file;
}

/// The scan result while it is being reviewed and corrected.
final scanDraftsProvider =
    NotifierProvider<ScanDraftController, List<DraftClass>>(
      ScanDraftController.new,
    );

class ScanDraftController extends Notifier<List<DraftClass>> {
  @override
  List<DraftClass> build() => const <DraftClass>[];

  void replaceAll(List<DraftClass> drafts) {
    state = List<DraftClass>.unmodifiable(drafts);
  }

  void update(DraftClass draft) {
    state = List<DraftClass>.unmodifiable([
      for (final item in state) item.id == draft.id ? draft : item,
    ]);
  }

  void remove(String id) {
    state = List<DraftClass>.unmodifiable(state.where((item) => item.id != id));
  }

  void add(DraftClass draft) {
    state = List<DraftClass>.unmodifiable([...state, draft]);
  }

  void clear() => state = const <DraftClass>[];
}
