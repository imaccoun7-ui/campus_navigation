import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/scheduled_class.dart';

/// Uploads and downloads the saved schedule for the signed-in student.
///
/// Offline-first on purpose: Hive stays the source of truth the UI renders
/// from, and this service is a best-effort mirror. Every call tolerates
/// being offline — they resolve harmlessly instead of throwing, so a dropped
/// connection never blocks a class edit. Firestore document fields match
/// `ScheduledClass.toJson()` one to one, so no mapping layer is needed.
class ScheduleSyncService {
  ScheduleSyncService(this._auth, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>>? _classesCollection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return null;
    }
    return _firestore.collection('users').doc(uid).collection('classes');
  }

  /// Replaces the remote schedule with [classes]. No-op when signed out.
  Future<void> push(List<ScheduledClass> classes) async {
    final collection = _classesCollection();
    if (collection == null) {
      return;
    }
    try {
      // Collections can't be deleted in one op — remove the stale docs first
      // (a class deleted on-device should disappear remotely too).
      final existing = await collection.get();
      final batch = _firestore.batch();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (final item in classes) {
        batch.set(collection.doc(item.id), item.toJson());
      }
      await batch.commit();
    } on FirebaseException {
      // Offline or denied — the local schedule is already saved.
    }
  }

  /// The remote schedule, or null when signed out / offline / nothing stored.
  Future<List<ScheduledClass>?> pull() async {
    final collection = _classesCollection();
    if (collection == null) {
      return null;
    }
    try {
      final snapshot = await collection.get(const GetOptions(source: Source.server));
      return snapshot.docs
          .map((doc) => ScheduledClass.fromJson(doc.data()))
          .toList(growable: false);
    } on FirebaseException {
      return null;
    }
  }
}

final scheduleSyncProvider = Provider<ScheduleSyncService>(
  (ref) => ScheduleSyncService(FirebaseAuth.instance),
);
