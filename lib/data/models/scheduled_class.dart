import 'dart:convert';

/// A day of the class week.
enum ClassDay {
  monday('Monday', 'Mon'),
  tuesday('Tuesday', 'Tue'),
  wednesday('Wednesday', 'Wed'),
  thursday('Thursday', 'Thu'),
  friday('Friday', 'Fri'),
  saturday('Saturday', 'Sat'),
  sunday('Sunday', 'Sun');

  const ClassDay(this.longLabel, this.shortLabel);

  final String longLabel;
  final String shortLabel;

  static ClassDay fromDateTime(DateTime date) => values[date.weekday - 1];

  /// Strict parse of a single day name or abbreviation.
  static ClassDay? parse(String token) {
    final value = token.trim().toLowerCase();
    if (value.isEmpty) {
      return null;
    }
    for (final day in values) {
      if (value == day.longLabel.toLowerCase() ||
          value == day.shortLabel.toLowerCase()) {
        return day;
      }
    }
    const aliases = <String, ClassDay>{
      'tues': ClassDay.tuesday,
      'tue': ClassDay.tuesday,
      'thur': ClassDay.thursday,
      'thurs': ClassDay.thursday,
      'weds': ClassDay.wednesday,
      'sat': ClassDay.saturday,
    };
    return aliases[value];
  }
}

/// A class on the student's saved schedule.
class ScheduledClass {
  const ScheduledClass({
    required this.id,
    required this.subject,
    required this.room,
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    this.buildingId,
    this.roomIndex,
    this.needsReview = false,
    this.note,
  });

  factory ScheduledClass.fromJson(Map<String, dynamic> json) {
    return ScheduledClass(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? 'Class',
      room: json['room'] as String? ?? '',
      day: ClassDay.values.firstWhere(
        (day) => day.name == json['day'],
        orElse: () => ClassDay.monday,
      ),
      startMinutes: (json['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (json['endMinutes'] as num?)?.toInt() ?? 0,
      buildingId: json['buildingId'] as String?,
      roomIndex: (json['roomIndex'] as num?)?.toInt(),
      needsReview: json['needsReview'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }

  static List<ScheduledClass> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return const <ScheduledClass>[];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ScheduledClass.fromJson)
        .toList(growable: false);
  }

  static String encodeList(List<ScheduledClass> classes) =>
      jsonEncode(classes.map((item) => item.toJson()).toList(growable: false));

  final String id;
  final String subject;

  /// Room string shown to the student (matched name, or the scanned text).
  final String room;

  final ClassDay day;
  final int startMinutes;
  final int endMinutes;

  /// Building matched from `buildings.json`, when the scan resolved one.
  final String? buildingId;

  /// Index of the matched room inside its building.
  final int? roomIndex;

  final bool needsReview;
  final String? note;

  bool get hasDirections => buildingId != null && roomIndex != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'room': room,
    'day': day.name,
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    if (buildingId != null) 'buildingId': buildingId,
    if (roomIndex != null) 'roomIndex': roomIndex,
    'needsReview': needsReview,
    if (note != null) 'note': note,
  };

  ScheduledClass copyWith({
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
  }) {
    return ScheduledClass(
      id: id,
      subject: subject ?? this.subject,
      room: room ?? this.room,
      day: day ?? this.day,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      buildingId: clearMatch ? null : (buildingId ?? this.buildingId),
      roomIndex: clearMatch ? null : (roomIndex ?? this.roomIndex),
      needsReview: needsReview ?? this.needsReview,
      note: note ?? this.note,
    );
  }
}
