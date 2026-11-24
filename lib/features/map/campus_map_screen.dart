import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/models/building.dart';
import '../../data/models/room.dart';
import '../../data/repositories/repository_providers.dart';
import '../route/route_providers.dart';
import 'widgets/campus_map_view.dart';

/// The interactive campus map.
///
/// There is no design file for this screen: it is derived from section 5 of the
/// brief using the `highfi/` design language (blue canvas, rounded white cards,
/// yellow controls).
class CampusMapScreen extends ConsumerStatefulWidget {
  const CampusMapScreen({
    super.key,
    this.initialBuildingId,
    this.initialRoomName,
    this.pickStartPoint = false,
  });

  final String? initialBuildingId;
  final String? initialRoomName;

  /// When true, a tap on the map drops the route's starting pin.
  final bool pickStartPoint;

  @override
  ConsumerState<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends ConsumerState<CampusMapScreen> {
  String? _selectedBuildingId;
  String? _highlightRoom;

  @override
  void initState() {
    super.initState();
    _selectedBuildingId = widget.initialBuildingId;
    _highlightRoom = widget.initialRoomName;
  }

  void _placeStart(Offset point) {
    final snapped = ref.read(pathfinderProvider).snapToRoad(point);
    ref
        .read(startSelectionProvider.notifier)
        .set(
          StartSelection(
            kind: StartKind.mapPoint,
            label: AppConfig.droppedPinLabel,
            imagePoint: snapped,
          ),
        );
    context.go('/start');
  }

  void _directionsFrom(Building building) {
    ref
        .read(destinationProvider.notifier)
        .set(Destination(buildingId: building.id));
    ref.read(startSelectionProvider.notifier).selectMainGate();
    context.push('/start');
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(campusDataProvider);
    final routePlan = ref.watch(routePlanProvider);
    final building = data.buildingById(_selectedBuildingId);

    return ScreenShell(
      scrollable: false,
      padding: EdgeInsets.zero,
      header: ScreenHeader(
        title: widget.pickStartPoint ? 'Starting Point' : 'Campus Map',
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                  child: CampusMapView(
                    data: data,
                    selectedBuildingId: widget.pickStartPoint
                        ? null
                        : _selectedBuildingId,
                    routePoints: routePlan?.path.points,
                    onBuildingTap: (tapped) {
                    if (widget.pickStartPoint) {
                      return;
                    }
                    setState(() {
                      _selectedBuildingId = tapped.id;
                      _highlightRoom = null;
                    });
                  },
                  onMapTap: widget.pickStartPoint ? _placeStart : null,
                ),
              ),
              if (widget.pickStartPoint)
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.screenPadding,
                  right: AppSpacing.screenPadding,
                  child: AppCard(
                    child: Text(
                      'Tap anywhere on the map to place your starting point. '
                      'It snaps to the nearest path.',
                      style: AppTypography.cardBody.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              if (!widget.pickStartPoint && building != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.58,
                    ),
                    child: _BuildingSheet(
                      building: building,
                      highlightRoom: _highlightRoom,
                      onClose: () => setState(() {
                        _selectedBuildingId = null;
                        _highlightRoom = null;
                      }),
                      onDirections: () => _directionsFrom(building),
                      onRoomTap: (room) => context.push(
                        '/room/${building.id}/${room.indexInBuilding}',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BuildingSheet extends ConsumerWidget {
  const _BuildingSheet({
    required this.building,
    required this.onClose,
    required this.onDirections,
    required this.onRoomTap,
    this.highlightRoom,
  });

  final Building building;
  final String? highlightRoom;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final ValueChanged<Room> onRoomTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedBuildingsProvider).contains(building.id);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: AppTypography.cardTitle.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        building.hasRoomData
                            ? '${building.floors.length} floors · '
                                  '${building.roomCount} rooms'
                            : 'No room details yet',
                        style: AppTypography.cardBody,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close building details',
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SheetAction(
                  icon: saved ? Icons.bookmark : Icons.bookmark_border,
                  label: saved ? 'Saved' : 'Save',
                  semanticLabel: saved ? 'Remove from saved' : 'Save building',
                  selected: saved,
                  onTap: () =>
                      ref.read(savedBuildingsProvider.notifier).toggle(building.id),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SheetAction(
                  icon: Icons.alt_route,
                  label: 'Directions',
                  semanticLabel: 'Get directions to ${building.name}',
                  onTap: onDirections,
                ),
              ],
            ),
          ),
          if (building.hasRoomData)
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                ),
                shrinkWrap: true,
                children: [
                  for (final floor in building.floors.reversed) ...[
                    Text(floor.label, style: AppTypography.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final room in floor.rooms)
                          AppChip(
                            label: room.name,
                            dense: true,
                            selected: room.name == highlightRoom,
                            onTap: () => onRoomTap(room),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.lg,
            ),
            child: _BuildingFooter(
              building: building,
              onDirections: onDirections,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Nearby" section styled after Google Maps' place sheet: a compact
/// directions prompt plus other buildings for quick jumping.
class _BuildingFooter extends ConsumerWidget {
  const _BuildingFooter({required this.building, required this.onDirections});

  final Building building;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final nearby = data.buildings
        .where((other) => other.id != building.id)
        .take(2)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (nearby.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nearby',
              style: AppTypography.cardTitle.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final other in nearby)
            _NearbyRow(
              building: other,
              onTap: () => context.push('/map?building=${other.id}'),
            ),
        ],
      ],
    );
  }
}

class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.building, required this.onTap});

  final Building building;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(building.name, style: AppTypography.cardBody.copyWith(color: AppColors.ink)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Compact icon-over-label action, the sheet equivalent of Google Maps'
/// Directions / Save / Share row.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDeep : AppColors.inkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
