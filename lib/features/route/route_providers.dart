import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/models/building.dart';
import '../../data/models/room.dart';
import '../../data/repositories/repository_providers.dart';
import '../../services/routing/pathfinder.dart';
import '../../services/routing/steps_builder.dart';

/// Where the student is walking to.
class Destination {
  const Destination({required this.buildingId, this.roomName, this.roomIndex});

  final String buildingId;
  final String? roomName;
  final int? roomIndex;
}

/// Where the student is walking from.
class StartSelection {
  const StartSelection({
    required this.kind,
    required this.label,
    this.gateName,
    this.buildingId,
    this.imagePoint,
  });

  final StartKind kind;
  final String label;

  /// Set when [kind] is [StartKind.gate].
  final String? gateName;

  /// Set when [kind] is [StartKind.landmark].
  final String? buildingId;

  /// Set when [kind] is [StartKind.mapPoint].
  final Offset? imagePoint;
}

/// Overridden in `main()` with the single [Pathfinder] instance.
final pathfinderProvider = Provider<Pathfinder>(
  (ref) => Pathfinder(ref.watch(campusDataProvider)),
);

final destinationProvider =
    NotifierProvider<DestinationController, Destination?>(
      DestinationController.new,
    );

class DestinationController extends Notifier<Destination?> {
  @override
  Destination? build() => null;

  void set(Destination? destination) => state = destination;

  void clear() => state = null;
}

final startSelectionProvider =
    NotifierProvider<StartSelectionController, StartSelection?>(
      StartSelectionController.new,
    );

class StartSelectionController extends Notifier<StartSelection?> {
  @override
  StartSelection? build() => null;

  void set(StartSelection? selection) => state = selection;

  void selectMainGate() {
    state = StartSelection(
      kind: StartKind.gate,
      label: AppConfig.mainGateName,
      gateName: AppConfig.mainGateName,
    );
  }
}

/// A fully computed route, including its walking instructions.
class RoutePlan {
  const RoutePlan({
    required this.path,
    required this.steps,
    required this.destination,
    required this.startLabel,
    this.room,
  });

  final RoutePath path;
  final List<String> steps;
  final Building destination;
  final Room? room;
  final String startLabel;
}

/// Recomputed whenever the destination or the start point changes.
final routePlanProvider = Provider<RoutePlan?>((ref) {
  final data = ref.watch(campusDataProvider);
  final destination = ref.watch(destinationProvider);
  if (destination == null) {
    return null;
  }
  final building = data.buildingById(destination.buildingId);
  if (building == null) {
    return null;
  }
  final pathfinder = ref.watch(pathfinderProvider);
  final start = ref.watch(startSelectionProvider) ?? _defaultStart;

  final nodeId = _nodeIdFor(pathfinder, start);
  if (nodeId == null) {
    return null;
  }
  final path = pathfinder.findRoute(
    fromNodeId: nodeId,
    toBuildingId: building.id,
  );
  if (path == null) {
    return null;
  }

  final room =
      building.roomByIndex(destination.roomIndex ?? -1) ??
      building.roomNamed(destination.roomName);
  final steps = const StepsBuilder().build(
    path: path,
    destination: building,
    room: room,
    startLabel: start.label,
    data: data,
  );

  return RoutePlan(
    path: path,
    steps: steps,
    destination: building,
    room: room,
    startLabel: start.label,
  );
});

const StartSelection _defaultStart = StartSelection(
  kind: StartKind.gate,
  label: AppConfig.mainGateName,
  gateName: AppConfig.mainGateName,
);

String? _nodeIdFor(Pathfinder pathfinder, StartSelection start) {
  switch (start.kind) {
    case StartKind.mapPoint:
      final point = start.imagePoint;
      if (point == null) {
        return null;
      }
      return pathfinder.nearestRoadNodeId(point);
    case StartKind.gate:
      return pathfinder.gateNodeId(start.gateName ?? AppConfig.mainGateName);
    case StartKind.landmark:
      final buildingId =
          start.buildingId ?? AppConfig.landmarkStartBuildings['Library'];
      if (buildingId == null) {
        return pathfinder.gateNodeId(AppConfig.mainGateName);
      }
      return pathfinder.buildingNodeId(buildingId) ??
          pathfinder.gateNodeId(AppConfig.mainGateName);
  }
}
