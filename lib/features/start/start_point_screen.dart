import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';
import '../../data/repositories/repository_providers.dart';
import '../route/route_providers.dart';

/// `highfi/11-set-starting-point.png`
///
/// The designs' rows without GPS: "Current Location" places a pin on the map,
/// and the brief's Cafeteria option is listed too.
class StartPointScreen extends ConsumerWidget {
  const StartPointScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(campusDataProvider);
    final destination = ref.watch(destinationProvider);
    final selection = ref.watch(startSelectionProvider);
    final building = data.buildingById(destination?.buildingId);

    if (destination == null || building == null) {
      return ScreenShell(
        header: const ScreenHeader(title: 'Set Starting Point'),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pick a room or building first.',
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: AppSpacing.md),
              PillButton(
                label: 'Open campus map',
                variant: PillButtonVariant.primary,
                onPressed: () => context.push('/map'),
              ),
            ],
          ),
        ),
      );
    }

    void choose(StartSelection next) =>
        ref.read(startSelectionProvider.notifier).set(next);

    final gateName = AppConfig.mainGateName;
    final buildingNames = data.buildings
        .map((building) => building.name.toLowerCase())
        .toSet();
    final landmarkOptions = AppConfig.landmarkStartBuildings.entries.where(
      (entry) => !buildingNames.contains(entry.key.toLowerCase()),
    );
    final options = <_StartOption>[
      _StartOption(
        label: 'Current Location',
        subtitle: 'Tap the map to place your starting point',
        selected: selection?.kind == StartKind.mapPoint,
        onTap: () => context.push('/map?pick=start'),
      ),
      _StartOption(
        label: 'Main Entrance',
        subtitle: gateName,
        selected:
            selection?.kind == StartKind.gate &&
            (selection?.gateName ?? gateName) == gateName,
        onTap: () => choose(
          StartSelection(
            kind: StartKind.gate,
            label: gateName,
            gateName: gateName,
          ),
        ),
      ),
      for (final entry in landmarkOptions)
        _StartOption(
          label: entry.key,
          subtitle: data.buildingById(entry.value)?.name ?? '',
          selected:
              selection?.kind == StartKind.landmark &&
              selection?.buildingId == entry.value &&
              selection?.label == entry.key,
          onTap: () => choose(
            StartSelection(
              kind: StartKind.landmark,
              label: entry.key,
              buildingId: entry.value,
            ),
          ),
        ),
    ];

    return ScreenShell(
      header: const ScreenHeader(title: 'Set Starting Point'),
      bottom: PillButton(
        label: 'Start Route',
        variant: PillButtonVariant.onCanvas,
        onPressed: () {
          ref
              .read(startSelectionProvider.notifier)
              .set(
                selection ??
                    StartSelection(
                      kind: StartKind.gate,
                      label: gateName,
                      gateName: gateName,
                    ),
              );
          context.push('/route');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DESTINATION', style: AppTypography.eyebrowMuted),
                const SizedBox(height: 2),
                Text(
                  destination.roomName == null
                      ? building.name
                      : '${building.name}, ${destination.roomName}',
                  style: AppTypography.cardTitle,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Where are you starting from?',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final option in options) ...[
            _StartOptionTile(option: option),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Text('Buildings', style: AppTypography.eyebrowMuted),
          const SizedBox(height: AppSpacing.sm),
          for (final building in data.buildings) ...[
            _StartOptionTile(
              option: _StartOption(
                label: building.name,
                subtitle: '',
                selected:
                    selection?.kind == StartKind.landmark &&
                    selection?.buildingId == building.id &&
                    selection?.label == building.name,
                onTap: () => choose(
                  StartSelection(
                    kind: StartKind.landmark,
                    label: building.name,
                    buildingId: building.id,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _StartOption {
  const _StartOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
}

class _StartOptionTile extends StatelessWidget {
  const _StartOptionTile({required this.option});

  final _StartOption option;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: option.selected,
      label: '${option.label}. ${option.subtitle}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: InkWell(
          onTap: option.onTap,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
              border: Border.all(
                color: option.selected
                    ? AppColors.primaryDeep
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: AppTypography.cardTitle),
                      if (option.subtitle.isNotEmpty)
                        Text(option.subtitle, style: AppTypography.cardBody),
                    ],
                  ),
                ),
                if (option.selected)
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.primaryDeep,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
