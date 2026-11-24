import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/building.dart';
import '../../../data/models/road_graph.dart';

/// Paints building highlights, the walking route and the hidden road-graph
/// overlay on top of the illustrated campus map.
///
/// Everything is drawn in image pixels: the [InteractiveViewer] applies the
/// pan/zoom transform, so the painter never deals with screen coordinates.
class CampusMapPainter extends CustomPainter {
  CampusMapPainter({
    required this.buildings,
    required this.roads,
    this.selectedBuildingId,
    this.routePoints,
    this.showRoadGraph = false,
  });

  final List<Building> buildings;
  final RoadGraph roads;
  final String? selectedBuildingId;
  final List<Offset>? routePoints;
  final bool showRoadGraph;

  @override
  void paint(Canvas canvas, Size size) {
    if (showRoadGraph) {
      _paintRoadGraph(canvas);
    }

    final selected = selectedBuildingId == null
        ? null
        : buildings
              .where((building) => building.id == selectedBuildingId)
              .firstOrNull;

    if (selected != null) {
      canvas.drawPath(
        selected.path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = AppColors.buildingHighlight,
      );
      canvas.drawPath(
        selected.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.buildingHighlightStroke,
      );
    }

    final points = routePoints;
    if (points != null && points.length > 1) {
      _paintRoute(canvas, points);
    }
  }

  void _paintRoute(Canvas canvas, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 8
        ..color = AppColors.onCanvas,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 5
        ..color = AppColors.routeLine,
    );

    _paintMarker(canvas, points.first, AppColors.routeStart);
    _paintMarker(canvas, points.last, AppColors.routeEnd);
  }

  void _paintMarker(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      9,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppColors.onCanvas,
    );
    canvas.drawCircle(
      center,
      6.5,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  void _paintRoadGraph(Canvas canvas) {
    final nodePaint = Paint()..color = AppColors.debugRoad;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.debugRoad.withValues(alpha: 0.55);

    for (final edge in roads.edges) {
      final a = roads.nodes[edge.a];
      final b = roads.nodes[edge.b];
      if (a == null || b == null) {
        continue;
      }
      canvas.drawLine(a, b, edgePaint);
    }
    roads.nodes.forEach((_, point) {
      canvas.drawCircle(point, 2.5, nodePaint);
    });
  }

  @override
  bool shouldRepaint(covariant CampusMapPainter oldDelegate) {
    return oldDelegate.selectedBuildingId != selectedBuildingId ||
        oldDelegate.showRoadGraph != showRoadGraph ||
        oldDelegate.routePoints != routePoints ||
        oldDelegate.buildings != buildings;
  }
}
