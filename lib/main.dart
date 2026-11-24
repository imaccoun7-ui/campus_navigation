import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/repositories/campus_repository.dart';
import 'data/repositories/repository_providers.dart';
import 'data/repositories/room_details_repository.dart';
import 'features/route/route_providers.dart';
import 'firebase_options.dart';
import 'services/routing/pathfinder.dart';

/// Loads the campus data once, then hands it to the widget tree through
/// overrides so no screen ever re-parses the JSON.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('campus_nav');

  const campusRepository = CampusRepository();
  const roomDetailsRepository = RoomDetailsRepository();
  final campus = await campusRepository.load();
  final roomDetails = await roomDetailsRepository.load();

  runApp(
    ProviderScope(
      overrides: [
        campusDataProvider.overrideWithValue(campus),
        roomDetailsProvider.overrideWithValue(roomDetails),
        storageBoxProvider.overrideWithValue(box),
        pathfinderProvider.overrideWithValue(Pathfinder(campus)),
      ],
      child: const CampusNavApp(),
    ),
  );
}
