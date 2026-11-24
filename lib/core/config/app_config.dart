import 'package:flutter/widgets.dart';

/// How a route's starting point was chosen.
enum StartKind {
  /// Student taps the illustrated map to drop a pin.
  mapPoint,

  /// One of the campus gates.
  gate,

  /// A named landmark building (Library, Cafeteria, Student Center).
  landmark,
}

/// Static configuration shared by routing, the map and the study-load scanner.
///
/// Everything that depends on real-world measurement lives here so it can be
/// corrected in one place.
abstract final class AppConfig {
  // ---------------------------------------------------------------------------
  // Scale
  // ---------------------------------------------------------------------------

  /// How many real metres one pixel of the 1346 x 1168 illustration represents.
  ///
  /// Measured against OpenStreetMap footprints of three buildings that are also
  /// labelled on the illustration, by comparing the real distance between them
  /// with the pixel distance between the same outline centroids:
  ///
  ///   Gymnasium <-> Student Center   94.5 m / 355 px -> 0.266 m/px
  ///   Gymnasium <-> Andaya Building  42.4 m / 183 px -> 0.232 m/px
  ///   Student Center <-> Andaya     120.7 m / 465 px -> 0.260 m/px
  ///
  /// 0.26 is the median. The illustration is stylised, so treat it as +/-7%.
  /// Replace it with a tape-measured gate-to-gate distance when one is taken.
  static const double metersPerPixel = 0.26;

  /// Average walking speed used for the time estimate.
  static const double walkingMetersPerMinute = 80;

  /// True while [metersPerPixel] is still a guess. False once the value above
  /// is backed by the measurements documented there.
  static const bool scaleIsApproximate = false;

  // ---------------------------------------------------------------------------
  // Starting points
  // ---------------------------------------------------------------------------

  /// Which gate in `buildings.json` is the "Main Gate".
  ///
  /// Assumption confirmed by the project owner: the First Gate is the main gate.
  /// Change this string to "Second Gate" to switch.
  static const String mainGateName = 'First Gate';

  /// Landmark starting points, mapped to the buildings that host them.
  ///
  /// Library  -> School of Management and Entrepreneurship (Library on floors 2-3)
  /// Cafeteria -> School of Technology and Computer Studies (Cafeteria on floor 4)
  static const Map<String, String> landmarkStartBuildings = <String, String>{
    'Library': 'sme',
    'Cafeteria': 'stcs',
    'Student Center': 'student',
  };

  /// Label shown for the "Current Location" (tap-the-map) option.
  static const String droppedPinLabel = 'Dropped pin';

  // ---------------------------------------------------------------------------
  // Routing
  // ---------------------------------------------------------------------------

  /// Distance between generated points along a road edge, in image pixels.
  static const double roadDensifySpacing = 20;

  /// Maximum distance (px) from a route to include a building as a landmark.
  static const double landmarkSearchRadius = 140;

  // ---------------------------------------------------------------------------
  // Map viewport
  // ---------------------------------------------------------------------------

  /// Zoom range, expressed as a multiple of the fit-to-screen scale.
  static const double minZoomFactor = 0.8;
  static const double maxZoomFactor = 6;

  /// Padding used when fitting the map or a building into the viewport.
  static const double mapFitPadding = 16;

  // ---------------------------------------------------------------------------
  // Assets
  // ---------------------------------------------------------------------------

  static const String mapImageAsset = 'assets/map/campus_map.png';
  static const String logoAsset = 'assets/images/logo.png';
  static const String buildingsAsset = 'assets/data/buildings.json';
  static const String roomDetailsAsset = 'assets/data/room_details.json';

  /// Text shown wherever campus data does not exist yet.
  static const String notAvailable = 'Not available yet';

  /// Flag used to show onboarding only once.
  static const String onboardingSeenKey = 'onboarding_seen';

  /// Padding helper for map fitting.
  static Rect inflate(Rect rect, double amount) => rect.inflate(amount);
}
