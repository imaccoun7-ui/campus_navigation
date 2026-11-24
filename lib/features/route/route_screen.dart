import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/format/time_format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import 'route_providers.dart';

/// `highfi/12-route.png`
class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(routePlanProvider);
    final destination = ref.watch(destinationProvider);

    if (plan == null || destination == null) {
      return ScreenShell(
        header: const ScreenHeader(title: 'Route'),
        child: const AppCard(
          child: Text(
            'No route could be drawn to that place yet.',
            style: AppTypography.cardBody,
          ),
        ),
      );
    }

    final title = plan.room == null ? plan.destination.name : plan.room!.name;
    final approximate = AppConfig.scaleIsApproximate;

    return ScreenShell(
      header: const ScreenHeader(title: 'Route'),
      bottom: PillButton(
        label: 'End Route',
        variant: PillButtonVariant.onCanvas,
        onPressed: () => context.push('/arrival'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('To', style: AppTypography.eyebrowMuted),
                const SizedBox(height: 2),
                Text(title, style: AppTypography.cardTitle),
                if (plan.room != null)
                  Text(plan.destination.name, style: AppTypography.cardBody),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${approximate ? '≈ ' : ''}${formatWalkTime(plan.path.duration)}'
            '  ·  '
            '${approximate ? '≈ ' : ''}'
            '${formatDistance(plan.path.meters)}',
            style: AppTypography.cardTitle.copyWith(
              color: AppColors.onCanvas,
              fontSize: 12.5,
            ),
          ),
          if (approximate)
            Text(
              'Approximate: the map scale is not calibrated yet.',
              style: AppTypography.caption.copyWith(fontSize: 10.5),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Text('STEP DETAILS', style: AppTypography.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < plan.steps.length; index++) ...[
            AppCard(
              color: AppColors.field,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${index + 1}.', style: AppTypography.cardTitle),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      plan.steps[index],
                      style: AppTypography.cardBody.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          PillButton(
            label: 'View route on map',
            variant: PillButtonVariant.surface,
            onPressed: () =>
                context.push('/map?building=${plan.destination.id}'),
          ),
        ],
      ),
    );
  }
}
