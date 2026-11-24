import 'package:intl/intl.dart';

/// Formats a minute-of-day value as a clock time (`"9:00 AM"`).
String formatClock(int minutesOfDay) {
  final clamped = minutesOfDay % (24 * 60);
  final date = DateTime(2000, 1, 1, clamped ~/ 60, clamped % 60);
  return DateFormat('h:mm a').format(date);
}

/// Formats a duration in minutes as `"6 min"` or `"1 hr 5 min"`.
String formatWalkTime(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) {
    return '$minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// Formats a distance in metres, switching to kilometres past 1000 m.
String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
  return '${meters.round()} m';
}
