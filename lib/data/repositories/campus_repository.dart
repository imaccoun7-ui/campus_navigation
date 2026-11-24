import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/config/app_config.dart';
import '../models/campus_data.dart';

/// Loads `assets/data/buildings.json` exactly once, at start-up.
class CampusRepository {
  const CampusRepository();

  Future<CampusData> load() async {
    final raw = await rootBundle.loadString(AppConfig.buildingsAsset);
    return parse(raw);
  }

  /// Pure parser, used by tests and by [load].
  CampusData parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('buildings.json must contain a JSON object');
    }
    return CampusData.fromJson(decoded);
  }
}
