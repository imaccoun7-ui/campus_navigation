import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';

/// `highfi/01-splash.png`
///
/// Rebuilt splash: content is centered by a plain [Column] whose spacers are
/// equal, so it cannot drift. The red frame and yellow diagnostic chip from
/// the debugging pass are kept in the tree but hidden, so the layout that
/// verified as correct is preserved exactly while nothing is visibly drawn.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mq = MediaQuery.of(context);
              final view = View.of(context);
              final debug = 'cm ${constraints.maxWidth.toStringAsFixed(0)}x'
                  '${constraints.maxHeight.toStringAsFixed(0)}\n'
                  'mq ${mq.size.width.toStringAsFixed(0)}x'
                  '${mq.size.height.toStringAsFixed(0)}\n'
                  'dpr ${mq.devicePixelRatio.toStringAsFixed(2)}  '
                  'phys ${view.physicalSize.width.toStringAsFixed(0)}x'
                  '${view.physicalSize.height.toStringAsFixed(0)}\n'
                  'pad l${mq.padding.left.toStringAsFixed(0)} '
                  'r${mq.padding.right.toStringAsFixed(0)}';
              return Container(
                decoration: BoxDecoration(
                  // Red diagnostic frame, hidden: same 1px geometry as the
                  // debug pass, nothing visibly drawn.
                  border: Border.all(color: Colors.transparent, width: 1),
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 1),
                    const CampusNavLogo(size: 186),
                    const SizedBox(height: AppSpacing.xxl),
                    const Text(
                      'CAMPUS NAV',
                      style: AppTypography.wordMark,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDeep,
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                      ),
                      child: const Text(
                        '“Never get lost on Campus”',
                        style: AppTypography.tagline,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Diagnostic chip, hidden: maintainSize keeps the exact
                    // layout that verified as correct.
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        color: const Color(0xFFFFF8DC),
                        child: Text(
                          debug,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontFamily: 'monospace',
                            color: Color(0xFF1E1E1F),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(flex: 1),
                    SizedBox(
                      width: 236,
                      child: PillButton(
                        label: 'Get Started',
                        variant: PillButtonVariant.primary,
                        onPressed: () => context.go('/onboarding'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl + AppSpacing.md),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
