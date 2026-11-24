import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/repositories/repository_providers.dart';
import '../route/route_providers.dart';

/// `highfi/10-room-details.png`
class RoomDetailsScreen extends ConsumerWidget {
  const RoomDetailsScreen({
    super.key,
    required this.buildingId,
    required this.roomIndex,
  });

  final String buildingId;
  final int roomIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final details = ref.watch(roomDetailsProvider);
    final repository = ref.watch(roomDetailsRepositoryProvider);
    final building = data.buildingById(buildingId);
    final room = building?.roomByIndex(roomIndex);

    if (building == null || room == null) {
      return ScreenShell(
        header: const ScreenHeader(title: 'Room Details'),
        child: const AppCard(
          child: Text(
            'That room is not in the campus data.',
            style: AppTypography.cardBody,
          ),
        ),
      );
    }

    final detail = repository.detailsFor(details, building.id, room.name);

    return ScreenShell(
      header: const ScreenHeader(title: 'Room Details'),
      bottom: PillButton(
        label: 'Get Directions',
        variant: PillButtonVariant.onCanvas,
        onPressed: () {
          ref
              .read(destinationProvider.notifier)
              .set(
                Destination(
                  buildingId: building.id,
                  roomName: room.name,
                  roomIndex: room.indexInBuilding,
                ),
              );
          ref.read(startSelectionProvider.notifier).selectMainGate();
          context.push('/start');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.name,
            style: AppTypography.screenHeading.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 2),
          Text(
            '${building.name} > ${room.floorLabel}',
            style: AppTypography.canvasBody.copyWith(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),
          DetailRow(label: 'Type', value: detail.typeLabel),
          DetailRow(label: 'Floor', value: room.floorLabel),
          DetailRow(label: 'Capacity', value: detail.capacityLabel),
          DetailRow(label: 'Accessibility', value: detail.accessibilityLabel),
          if (building.hasRoomData) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${building.roomCount} rooms are listed in this building. '
              'Capacity and accessibility are filled in from '
              '${AppConfig.roomDetailsAsset.split('/').last}.',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}
