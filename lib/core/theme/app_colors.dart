import 'package:flutter/material.dart';

/// Colour tokens sampled directly from the `highfi/` designs.
///
/// Every value here was measured from the PNG exports, so screens should never
/// hard-code a colour of their own.
abstract final class AppColors {
  /// The full-bleed blue used as the canvas on every screen.
  static const Color canvas = Color(0xFF4E88DF);

  /// Dark blue used by the bottom navigation bar and small accents.
  static const Color canvasDeep = Color(0xFF2A55AA);

  /// Primary action yellow (buttons, back circles, icon tiles).
  static const Color primary = Color(0xFFFFD93B);

  /// Deeper gold used for chips, the Log in button and selected states.
  static const Color primaryDeep = Color(0xFFDBC623);

  /// Card and sheet fill.
  static const Color surface = Color(0xFFF1F3F6);

  /// Grey fill for secondary buttons and media placeholders.
  static const Color surfaceMuted = Color(0xFFD9D9D9);

  /// Upload drop-zone fill.
  static const Color dropZone = Color(0xFFA1B8DB);

  /// Text field fill.
  static const Color field = Color(0xFFF7F8FA);

  /// Alternate text field fill (login password field in the design).
  static const Color fieldAlt = Color(0xFFFDFEF8);

  /// Arrival confirmation green.
  static const Color success = Color(0xFF22A55B);

  /// Primary ink used on light surfaces.
  static const Color ink = Color(0xFF1E1E1F);

  /// Secondary ink used on light surfaces.
  static const Color inkMuted = Color(0xFF5B5B5C);

  /// Text and icons on the blue canvas.
  static const Color onCanvas = Color(0xFFFFFFFF);

  /// Muted text on the blue canvas.
  static const Color onCanvasMuted = Color(0xFFDCE7F9);

  /// Hairline borders.
  static const Color outline = Color(0xFFBEBEBE);

  /// Navy used by the app logo mark.
  static const Color logoNavy = Color(0xFF14283C);

  /// Gold used by the app logo mark.
  static const Color logoGold = Color(0xFFC79A2A);

  /// Cream behind the logo mark.
  static const Color logoBackdrop = Color(0xFFFDFDF2);

  /// Route line drawn on the illustrated map.
  static const Color routeLine = Color(0xFF1B57C4);

  /// Route start marker.
  static const Color routeStart = Color(0xFF22A55B);

  /// Route end marker.
  static const Color routeEnd = Color(0xFFD64541);

  /// Highlight fill for the selected building.
  static const Color buildingHighlight = Color(0x66FFD93B);

  /// Highlight outline for the selected building.
  static const Color buildingHighlightStroke = Color(0xFFDBC623);

  /// Debug road-graph overlay.
  static const Color debugRoad = Color(0xCCFF4081);
}
