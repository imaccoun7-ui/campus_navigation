import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale taken from the `highfi/` designs.
///
/// The mockups use a Poppins-style geometric bold for headings; Poppins is
/// bundled in `assets/fonts` so the app keeps working offline. Sizes are left
/// in logical pixels and the app never sets `textScaler`, so the system font
/// size setting still applies everywhere.
abstract final class AppTypography {
  static const String family = 'Poppins';

  /// "CAMPUS NAV" word mark.
  static const TextStyle wordMark = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.4,
    color: AppColors.onCanvas,
  );

  /// Large screen-level heading ("Home").
  static const TextStyle screenHeading = TextStyle(
    fontFamily: family,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.onCanvas,
  );

  /// Centred header title ("Room Details", "My Schedule").
  static const TextStyle headerTitle = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.onCanvas,
  );

  /// Section heading on the blue canvas ("Today's Classes").
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.onCanvas,
  );

  /// Supporting sentence on the blue canvas.
  static const TextStyle canvasBody = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.onCanvasMuted,
  );

  /// All-caps label ("STEP DETAILS", "ROOM INFORMATION").
  static const TextStyle eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.onCanvas,
  );

  /// All-caps label on a light card ("DESTINATION").
  static const TextStyle eyebrowMuted = TextStyle(
    fontFamily: family,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.inkMuted,
  );

  /// Title inside a light card.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  /// Body copy inside a light card.
  static const TextStyle cardBody = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.inkMuted,
  );

  /// Emphasis value on the right of a detail row.
  static const TextStyle cardValue = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  /// Pill button label.
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  /// Small caption ("Supported: JPG, PNG, PDF").
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onCanvasMuted,
  );

  /// Tagline chip text.
  static const TextStyle tagline = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}
