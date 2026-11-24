import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format/time_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/models/campus_data.dart';
import '../../data/models/scheduled_class.dart';
import '../../data/repositories/repository_providers.dart';
import '../route/route_providers.dart';

/// `highfi/08-my-schedule.png`
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late ClassDay _selected = ClassDay.fromDateTime(DateTime.now());

  List<ClassDay> _visibleDays(List<ScheduledClass> schedule) {
    final days = <ClassDay>[...ClassDay.values.take(5)];
    if (schedule.any((item) => item.day == ClassDay.saturday)) {
      days.add(ClassDay.saturday);
    }
    if (schedule.any((item) => item.day == ClassDay.sunday)) {
      days.add(ClassDay.sunday);
    }
    return days;
  }

  DateTime _dateFor(ClassDay day) {
    final now = DateTime.now();
    final delta = (day.index - ClassDay.fromDateTime(now).index) % 7;
    return now.add(Duration(days: delta));
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(scheduleProvider);
    final data = ref.watch(campusDataProvider);
    final days = _visibleDays(schedule);
    final selected = days.contains(_selected) ? _selected : days.first;
    final classes = schedule.where((item) => item.day == selected).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return ScreenShell(
      navIndex: 1,
      header: const ScreenHeader(title: 'My Schedule', showBack: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final day in days) ...[
                  AppChip(
                    label: day.shortLabel,
                    selected: day == selected,
                    onTap: () => setState(() => _selected = day),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            DateFormat('EEEE, MMMM d').format(_dateFor(selected)),
            style: AppTypography.canvasBody.copyWith(
              color: AppColors.onCanvas,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (classes.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: 'Add Class',
                    variant: PillButtonVariant.surface,
                    icon: Icons.add_circle_outline,
                    onPressed: () => context.push('/schedule/create'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          if (classes.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No classes on ${selected.longLabel}',
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upload your study load to build your schedule.',
                    style: AppTypography.cardBody,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PillButton(
                    label: 'Upload Study Load',
                    variant: PillButtonVariant.primary,
                    onPressed: () => context.push('/upload'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PillButton(
                    label: 'Add Class Manually',
                    variant: PillButtonVariant.surface,
                    icon: Icons.add_circle_outline,
                    onPressed: () => context.push('/schedule/create'),
                  ),
                ],
              ),
            )
          else
            for (final item in classes) ...[
              AppCard(
                onTap: () => _openRoom(context, item),
                semanticLabel:
                    '${item.subject}, ${formatClock(item.startMinutes)}',
                child: Row(
                  children: [
                    SizedBox(
                      width: 68,
                      child: Text(
                        formatClock(item.startMinutes),
                        style: AppTypography.cardTitle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.subject, style: AppTypography.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            _locationLabel(item, data),
                            style: AppTypography.cardBody,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: item.hasDirections
                          ? () => _directions(context, item)
                          : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: const Size(0, AppSpacing.minTapTarget),
                      ),
                      child: Text(
                        'Directions',
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.inkMuted,
                      ),
                      onPressed: () =>
                          context.push('/schedule/edit/${item.id}'),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.routeEnd,
                      ),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }

  String _locationLabel(ScheduledClass item, CampusData data) {
    final building = data.buildingById(item.buildingId);
    if (building == null) {
      return item.room;
    }
    return '${building.name}, ${item.room}';
  }

  void _openRoom(BuildContext context, ScheduledClass item) {
    if (item.hasDirections) {
      context.push('/room/${item.buildingId}/${item.roomIndex}');
    }
  }

  void _directions(BuildContext context, ScheduledClass item) {
    ref
        .read(destinationProvider.notifier)
        .set(
          Destination(
            buildingId: item.buildingId!,
            roomName: item.room,
            roomIndex: item.roomIndex,
          ),
        );
    ref.read(startSelectionProvider.notifier).selectMainGate();
    context.push('/start');
  }

  Future<void> _confirmDelete(BuildContext context, ScheduledClass item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete class?'),
        content: Text(
          'Remove ${item.subject} (${item.room}) from your schedule?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.routeEnd,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(scheduleProvider.notifier).remove(item.id);
    }
  }
}
