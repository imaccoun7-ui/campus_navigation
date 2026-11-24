import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/screen_layout.dart';

/// `highfi/02-onboarding.png`
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const List<({IconData icon, String title, String body})> _features = [
    (
      icon: Icons.place_outlined,
      title: 'Find rooms',
      body: 'Quickly find your classroom or any room on campus',
    ),
    (
      icon: Icons.document_scanner_outlined,
      title: 'Scan your study load',
      body: 'Upload or take a photo of your study',
    ),
    (
      icon: Icons.alt_route,
      title: 'Get directions',
      body: 'Get step-by-step directions to your classroom',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    void finish() => context.go('/login');

    return ScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 120),
          for (final feature in _features) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconTile(icon: feature.icon),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(feature.title, style: AppTypography.cardTitle),
                        const SizedBox(height: 2),
                        Text(feature.body, style: AppTypography.cardBody),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: 120),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Next',
                  variant: PillButtonVariant.surface,
                  onPressed: finish,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: PillButton(
                  label: 'Skip',
                  variant: PillButtonVariant.primary,
                  onPressed: finish,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
