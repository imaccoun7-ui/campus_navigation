import '../../data/models/scheduled_class.dart';

/// A class row while it is still being reviewed.
///
/// Unlike [ScheduledClass] every field may be missing, because the scanner is
/// allowed to hand back partial rows that the student must complete.
class DraftClass {
  const DraftClass({
    required this.id,
    required this.subject,
    required this.room,
    this.day,
    this.startMinutes,
    this.endMinutes,
    this.buildingId,
    this.roomIndex,
    this.needsReview = false,
    this.note,
  });

  factory DraftClass.blank(String id) =>
      DraftClass(id: id, subject: '', room: '', needsReview: true);

  final String id;
  final String subject;
  final String room;
  final ClassDay? day;
  final int? startMinutes;
  final int? endMinutes;
  final String? buildingId;
  final int? roomIndex;
  final bool needsReview;
  final String? note;

  bool get isComplete =>
      subject.trim().isNotEmpty &&
      room.trim().isNotEmpty &&
      day != null &&
      startMinutes != null &&
      endMinutes != null;

  /// Shown under the subject: "Mon 9:00 AM > Room 204".
  String get summary {
    final dayLabel = day?.shortLabel ?? 'Day?';
    final start = startMinutes == null ? '--:--' : _clock(startMinutes!);
    final end = endMinutes == null ? '' : ' - ${_clock(endMinutes!)}';
    final roomLabel = room.trim().isEmpty ? 'Room?' : room;
    return '$dayLabel $start$end > $roomLabel';
  }

  String get issue => note ?? 'Check details';

  DraftClass copyWith({
    String? subject,
    String? room,
    ClassDay? day,
    int? startMinutes,
    int? endMinutes,
    String? buildingId,
    int? roomIndex,
    bool? needsReview,
    String? note,
    bool clearMatch = false,
    bool clearNote = false,
  }) {
    return DraftClass(
      id: id,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      day: day ?? this.day,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      buildingId: clearMatch ? null : (buildingId ?? this.buildingId),
      roomIndex: clearMatch ? null : (roomIndex ?? this.roomIndex),
      needsReview: needsReview ?? this.needsReview,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  ScheduledClass? toScheduledClass() {
    if (!isComplete) {
      return null;
    }
    return ScheduledClass(
      id: id,
      subject: subject.trim(),
      room: room.trim(),
      day: day!,
      startMinutes: startMinutes!,
      endMinutes: endMinutes!,
      buildingId: buildingId,
      roomIndex: roomIndex,
      needsReview: needsReview,
      note: note,
    );
  }

  static String _clock(int minutes) {
    final hour24 = minutes ~/ 60 % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour:${minute.toString().padLeft(2, '0')} $period';
  }
}
