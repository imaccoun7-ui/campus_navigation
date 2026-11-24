import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_widgets.dart';

/// Shared blue canvas with an optional header and bottom navigation.
class ScreenShell extends StatelessWidget {
  const ScreenShell({
    super.key,
    required this.child,
    this.header,
    this.navIndex,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenPadding,
    ),
    this.bottom,
  });

  final Widget child;
  final Widget? header;

  /// When set, the dark blue bottom navigation is shown with this tab active.
  final int? navIndex;

  final bool scrollable;
  final EdgeInsetsGeometry padding;

  /// Pinned content below the scroll area (for example a button stack).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final content = scrollable
        ? SingleChildScrollView(padding: padding, child: child)
        : Padding(padding: padding, child: child);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            Expanded(child: content),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  0,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
      bottomNavigationBar: navIndex == null
          ? null
          : AppBottomNav(selectedIndex: navIndex!),
    );
  }
}

/// Centred screen header with the yellow back circle from the designs.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions = const <Widget>[],
    this.large = false,
    this.subtitle,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Left-aligned 26pt heading (the Home screen) instead of the centred title.
  final bool large;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final back = showBack
        ? CircleIconButton(
            icon: Icons.arrow_back,
            semanticLabel: 'Back',
            onPressed:
                onBack ??
                () {
                  if (router?.canPop() ?? false) {
                    router!.pop();
                  } else {
                    router?.go('/home');
                  }
                },
          )
        : null;

    if (large) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.xl,
          AppSpacing.screenPadding,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: AppTypography.screenHeading),
                ),
                ...actions,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, style: AppTypography.canvasBody),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: AppSpacing.backButtonSize,
                child: back ?? const SizedBox.shrink(),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.headerTitle,
                ),
              ),
              SizedBox(
                width: AppSpacing.backButtonSize,
                child: actions.isEmpty
                    ? const SizedBox.shrink()
                    : OverflowBox(
                        maxWidth: 120,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions,
                        ),
                      ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.canvasBody,
            ),
          ],
        ],
      ),
    );
  }
}

/// The three-tab dark blue navigation bar from the designs.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.selectedIndex});

  final int selectedIndex;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      route: '/home',
    ),
    _NavItem(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Schedule',
      route: '/schedule',
    ),
    _NavItem(
      icon: Icons.search,
      selectedIcon: Icons.search,
      label: 'Search',
      route: '/search',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvasDeep,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.bottomNavHeight,
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: index == selectedIndex,
                    label: '${_items[index].label} tab',
                    child: InkWell(
                      onTap: () => context.go(_items[index].route),
                      child: Center(
                        child: Icon(
                          index == selectedIndex
                              ? _items[index].selectedIcon
                              : _items[index].icon,
                          size: 26,
                          color: index == selectedIndex
                              ? AppColors.onCanvas
                              : AppColors.onCanvas.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
}
