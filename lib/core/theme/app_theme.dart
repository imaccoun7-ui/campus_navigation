import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The single [ThemeData] for Campus Nav, built only from design tokens.
abstract final class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.ink,
      secondary: AppColors.primaryDeep,
      onSecondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.routeEnd,
      onError: AppColors.onCanvas,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: const TextTheme(
        headlineLarge: AppTypography.screenHeading,
        headlineSmall: AppTypography.headerTitle,
        titleMedium: AppTypography.sectionTitle,
        bodyMedium: AppTypography.canvasBody,
        bodySmall: AppTypography.caption,
        labelLarge: AppTypography.button,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.onCanvas,
        titleTextStyle: AppTypography.headerTitle,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: AppTypography.family,
          color: AppColors.onCanvas,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.sheetRadius),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: AppTypography.cardBody,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          borderSide: const BorderSide(
            color: AppColors.primaryDeep,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
