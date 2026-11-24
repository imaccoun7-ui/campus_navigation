import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// How a pill button should be filled.
enum PillButtonVariant { primary, gold, muted, surface, onCanvas }

/// The full-width rounded buttons used throughout the designs.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PillButtonVariant.surface,
    this.icon,
    this.height = AppSpacing.controlHeight,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;
  final IconData? icon;
  final double height;
  final bool expanded;

  Color get _fill => switch (variant) {
    PillButtonVariant.primary => AppColors.primary,
    PillButtonVariant.gold => AppColors.primaryDeep,
    PillButtonVariant.muted => AppColors.surfaceMuted,
    PillButtonVariant.surface => AppColors.surface,
    PillButtonVariant.onCanvas => AppColors.onCanvas,
  };

  Color get _foreground => switch (variant) {
    PillButtonVariant.onCanvas => AppColors.ink,
    _ => AppColors.ink,
  };

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: _foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.button.copyWith(color: _foreground),
          ),
        ),
      ],
    );

    final button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Material(
        color: onPressed == null ? _fill.withValues(alpha: 0.5) : _fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: SizedBox(
            height: height,
            width: expanded ? double.infinity : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AppSpacing.lg : AppSpacing.xl,
              ),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
    return button;
  }
}

/// A light card on the blue canvas.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.onTap,
    this.radius = AppSpacing.cardRadius,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) {
      return decorated;
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Yellow circular icon tile used in the onboarding and home cards.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.background = AppColors.primary,
    this.foreground = AppColors.logoNavy,
    this.size = 44,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}

/// Round icon button (the yellow back circle and header actions).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.background = AppColors.primary,
    this.foreground = AppColors.ink,
    this.size = AppSpacing.backButtonSize,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Label/value pill used on Room Details.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.primaryDeep.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.cardTitle)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.cardValue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field styled like the login and review forms.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: AppTypography.cardTitle,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: AppColors.inkMuted),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// The supplied app logo: cream disc, navy graduation cap and gold ribbon.
class CampusNavLogo extends StatelessWidget {
  const CampusNavLogo({super.key, this.size = 168});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Campus Nav logo',
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(
            AppConfig.logoAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Small rounded chip used for tags, filters and day selectors.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.background,
    this.foreground,
    this.selectedBackground = AppColors.primaryDeep,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;
  final Color selectedBackground;

  /// Smaller chip used inside the map's building sheet.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fill =
        background ?? (selected ? selectedBackground : AppColors.surface);
    final textColor =
        foreground ??
        (selected && background == null ? AppColors.ink : AppColors.ink);
    // The visual pill stays compact inside the map sheet, but the tap target
    // is always at least 48 dp tall.
    final pill = Container(
      constraints: BoxConstraints(minHeight: dense ? 34 : 44),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.md : AppSpacing.lg,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(
          color: selected ? AppColors.ink : Colors.transparent,
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.button.copyWith(
          fontSize: dense ? 11.5 : 13,
          fontWeight: dense ? FontWeight.w500 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          child: SizedBox(
            height: AppSpacing.minTapTarget,
            child: Center(widthFactor: 1, child: pill),
          ),
        ),
      ),
    );
  }
}
