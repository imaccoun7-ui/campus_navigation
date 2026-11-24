import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/time_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/models/scheduled_class.dart';
import '../../data/repositories/repository_providers.dart';

/// `highfi/04-home.png`
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(scheduleProvider);
    final today = ClassDay.fromDateTime(DateTime.now());
    final todays = schedule.where((item) => item.day == today).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return ScreenShell(
      navIndex: 0,
      header: ScreenHeader(
        title: 'Home',
        showBack: false,
        large: true,
        subtitle: 'Ready for your classes today?',
        actions: [
          CircleIconButton(
            icon: Icons.map_outlined,
            semanticLabel: 'Open campus map',
            onPressed: () => context.push('/map'),
          ),
          const SizedBox(width: AppSpacing.sm),
          CircleIconButton(
            icon: Icons.person_outline,
            semanticLabel: 'Account',
            onPressed: () => context.push('/login'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            onTap: () => context.push('/upload'),
            semanticLabel: 'Upload study load',
            child: Row(
              children: [
                const IconTile(icon: Icons.file_upload_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Study Load', style: AppTypography.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Scan your study load and create your '
                        'schedule automatically.',
                        style: AppTypography.cardBody,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: () => context.push('/search'),
            semanticLabel: 'Find a room',
            child: Row(
              children: [
                const IconTile(
                  icon: Icons.search,
                  background: AppColors.surfaceMuted,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Find a room', style: AppTypography.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        'Search classrooms, offices, and campus facilities.',
                        style: AppTypography.cardBody,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const Text("Today's Classes", style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          if (todays.isEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No classes today', style: AppTypography.cardTitle),
                  const SizedBox(height: 2),
                  Text(
                    'Upload your study load to fill this in.',
                    style: AppTypography.cardBody,
                  ),
                ],
              ),
            )
          else
            for (final item in todays) ...[
              AppCard(
                onTap: () => _openClass(context, item),
                semanticLabel:
                    '${item.subject} at ${formatClock(item.startMinutes)}',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 74,
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
                            _locationLabel(ref, item),
                            style: AppTypography.cardBody,
                          ),
                        ],
                      ),
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

  String _locationLabel(WidgetRef ref, ScheduledClass item) {
    final building = ref.read(campusDataProvider).buildingById(item.buildingId);
    if (building == null) {
      return item.room;
    }
    return '${building.name}, ${item.room}';
  }

  void _openClass(BuildContext context, ScheduledClass item) {
    if (item.buildingId != null && item.roomIndex != null) {
      context.push('/room/${item.buildingId}/${item.roomIndex}');
    } else {
      context.go('/schedule');
    }
  }
}
