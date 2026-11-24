import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/time_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/repositories/repository_providers.dart';
import '../route/route_providers.dart';

/// `highfi/13-arrival.png`
class ArrivalScreen extends ConsumerWidget {
  const ArrivalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final schedule = ref.watch(scheduleProvider);
    final details = ref.watch(roomDetailsProvider);
    final repository = ref.watch(roomDetailsRepositoryProvider);
    final destination = ref.watch(destinationProvider);
    final building = data.buildingById(destination?.buildingId);
    final room = destination?.roomIndex == null
        ? null
        : building?.roomByIndex(destination!.roomIndex!);

    final nextClass =
        schedule
            .where(
              (item) =>
                  item.buildingId == building?.id &&
                  (room == null || item.roomIndex == room.indexInBuilding),
            )
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final detail = room == null
        ? null
        : repository.detailsFor(details, building!.id, room.name);

    return ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: const Center(
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onCanvas,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'You have arrived!',
            textAlign: TextAlign.center,
            style: AppTypography.headerTitle.copyWith(fontSize: 19),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [building?.name, room?.name].whereType<String>().join(', '),
            textAlign: TextAlign.center,
            style: AppTypography.canvasBody,
          ),
          const SizedBox(height: 40),
          const Text('ROOM INFORMATION', style: AppTypography.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (room != null) _Pill(text: room.floorLabel),
                    if (detail != null) _Pill(text: detail.typeLabel),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  nextClass.isEmpty
                      ? 'No class is scheduled in this room.'
                      : '${nextClass.first.subject} starts at '
                            '${formatClock(nextClass.first.startMinutes)}',
                  style: AppTypography.cardBody.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (room != null && building != null)
            PillButton(
              label: 'View Room Details',
              variant: PillButtonVariant.onCanvas,
              onPressed: () =>
                  context.push('/room/${building.id}/${room.indexInBuilding}'),
            ),
          const SizedBox(height: AppSpacing.sm),
          PillButton(
            label: 'Back to Home',
            variant: PillButtonVariant.onCanvas,
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'Have a great class!',
              style: AppTypography.caption.copyWith(color: AppColors.onCanvas),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Text(
        text,
        style: AppTypography.cardBody.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
