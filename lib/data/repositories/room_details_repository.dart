import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/app_config.dart';

/// The editable per-room facts that `buildings.json` does not carry.
class RoomDetails {
  const RoomDetails({this.type, this.capacity, this.accessibility, this.notes});

  factory RoomDetails.fromJson(Map<String, dynamic> json) {
    return RoomDetails(
      type: json['type'] as String?,
      capacity: (json['capacity'] as num?)?.toInt(),
      accessibility: json['accessibility'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String? type;
  final int? capacity;
  final String? accessibility;
  final String? notes;

  String get typeLabel => type ?? AppConfig.notAvailable;
  String get capacityLabel =>
      capacity == null ? AppConfig.notAvailable : '$capacity seats';
  String get accessibilityLabel => accessibility ?? AppConfig.notAvailable;

  Map<String, dynamic> toJson() => {
    'type': type,
    'capacity': capacity,
    'accessibility': accessibility,
    'notes': notes ?? '',
  };
}

/// Loads the optional `assets/data/room_details.json` layer.
///
/// A missing or unreadable file is not an error: every room then simply reports
/// "Not available yet", which is the documented state until the data is filled
/// in by hand.
class RoomDetailsRepository {
  const RoomDetailsRepository();

  static String keyFor(String buildingId, String roomName) =>
      '$buildingId|$roomName';

  Future<Map<String, RoomDetails>> load() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.roomDetailsAsset);
      return parse(raw);
    } on Exception {
      return const <String, RoomDetails>{};
    }
  }

  Map<String, RoomDetails> parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const <String, RoomDetails>{};
    }
    final rooms = decoded['rooms'];
    if (rooms is! Map<String, dynamic>) {
      return const <String, RoomDetails>{};
    }
    final result = <String, RoomDetails>{};
    rooms.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = RoomDetails.fromJson(value);
      }
    });
    return result;
  }

  RoomDetails detailsFor(
    Map<String, RoomDetails> details,
    String buildingId,
    String roomName,
  ) {
    return details[keyFor(buildingId, roomName)] ?? const RoomDetails();
  }
}
