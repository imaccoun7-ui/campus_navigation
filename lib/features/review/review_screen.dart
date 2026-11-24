import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/repositories/repository_providers.dart';
import '../scan/scan_providers.dart';
import 'class_editor_sheet.dart';
import 'draft_class.dart';

/// `highfi/07-review-correct.png`
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(scanDraftsProvider);
    final flagged = drafts.where((draft) => draft.needsReview).length;

    return ScreenShell(
      header: const ScreenHeader(title: 'Review/Correct'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PillButton(
            label: 'Create Schedule',
            onPressed: () => _createSchedule(context, ref),
          ),
          const SizedBox(height: AppSpacing.sm),
          PillButton(
            label: 'Add Class',
            variant: PillButtonVariant.muted,
            onPressed: () => _addClass(context, ref),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Check the details before creating your schedule.',
            style: AppTypography.canvasBody,
          ),
          if (flagged > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$flagged class${flagged == 1 ? '' : 'es'} need '
                    'checking before you save.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onCanvas,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (drafts.isEmpty)
            const AppCard(
              child: Text(
                'Nothing scanned yet. Upload a study load to see your classes '
                'here.',
                style: AppTypography.cardBody,
              ),
            )
          else
            for (final draft in drafts) ...[
              AppCard(
                onTap: () => _edit(context, ref, draft),
                semanticLabel: 'Edit ${draft.subject}',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(draft.subject, style: AppTypography.cardTitle),
                          const SizedBox(height: 2),
                          Text(draft.summary, style: AppTypography.cardBody),
                          if (draft.needsReview) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              draft.issue,
                              style: AppTypography.cardBody.copyWith(
                                color: AppColors.canvasDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    CircleIconButton(
                      icon: Icons.edit_outlined,
                      semanticLabel: 'Edit ${draft.subject}',
                      size: 44,
                      onPressed: () => _edit(context, ref, draft),
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

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    DraftClass draft,
  ) async {
    final data = ref.read(campusDataProvider);
    final outcome = await showClassEditor(context, draft: draft, data: data);
    if (outcome == null) {
      return;
    }
    if (outcome.removed) {
      ref.read(scanDraftsProvider.notifier).remove(draft.id);
      return;
    }
    final updated = outcome.draft;
    if (updated != null) {
      ref.read(scanDraftsProvider.notifier).update(updated);
    }
  }

  Future<void> _addClass(BuildContext context, WidgetRef ref) async {
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    final draft = DraftClass.blank(id);
    ref.read(scanDraftsProvider.notifier).add(draft);
    final data = ref.read(campusDataProvider);
    final outcome = await showClassEditor(context, draft: draft, data: data);
    if (outcome == null) {
      return;
    }
    if (outcome.removed) {
      ref.read(scanDraftsProvider.notifier).remove(id);
      return;
    }
    final updated = outcome.draft;
    if (updated != null) {
      ref.read(scanDraftsProvider.notifier).update(updated);
    }
  }

  Future<void> _createSchedule(BuildContext context, WidgetRef ref) async {
    final drafts = ref.read(scanDraftsProvider);
    if (drafts.isEmpty) {
      _notify(context, 'Add at least one class first.');
      return;
    }
    final incomplete = drafts.where((draft) => !draft.isComplete).length;
    if (incomplete > 0) {
      _notify(
        context,
        '$incomplete class${incomplete == 1 ? '' : 'es'} still need a subject, '
        'room, day and time.',
      );
      return;
    }
    final classes = [for (final draft in drafts) draft.toScheduledClass()!];
    await ref.read(scheduleProvider.notifier).replaceAll(classes);
    ref.read(scanDraftsProvider.notifier).clear();
    if (!context.mounted) {
      return;
    }
    context.go('/schedule');
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
