import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/building.dart';
import '../../../data/models/campus_data.dart';
import 'campus_map_painter.dart';

/// The interactive campus map: the illustration, a paint layer for highlights
/// and the route, and hit testing in image space.
class CampusMapView extends StatefulWidget {
  const CampusMapView({
    super.key,
    required this.data,
    this.selectedBuildingId,
    this.routePoints,
    this.onBuildingTap,
    this.onMapTap,
    this.showRoadGraph = false,
  });

  final CampusData data;
  final String? selectedBuildingId;
  final List<Offset>? routePoints;
  final ValueChanged<Building>? onBuildingTap;
  final ValueChanged<Offset>? onMapTap;
  final bool showRoadGraph;

  @override
  State<CampusMapView> createState() => _CampusMapViewState();
}

class _CampusMapViewState extends State<CampusMapView> {
  final TransformationController _controller = TransformationController();

  Size _viewport = Size.zero;
  double _fitScale = 1;
  bool _didFit = false;
  bool _debugRoads = false;

  double get _minScale => _fitScale * AppConfig.minZoomFactor;
  double get _maxScale => _fitScale * AppConfig.maxZoomFactor;

  @override
  void initState() {
    super.initState();
    _debugRoads = widget.showRoadGraph;
  }

  @override
  void didUpdateWidget(covariant CampusMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedBuildingId != widget.selectedBuildingId &&
        widget.selectedBuildingId != null) {
      final building = widget.data.buildingById(widget.selectedBuildingId);
      if (building != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focusOnRect(building.bounds);
          }
        });
      }
    }
    if (oldWidget.routePoints != widget.routePoints &&
        widget.routePoints != null &&
        widget.routePoints!.isNotEmpty &&
        widget.selectedBuildingId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusOnRect(_routeBounds(widget.routePoints!));
        }
      });
    }
  }

  Rect _routeBounds(List<Offset> points) {
    var left = points.first.dx;
    var top = points.first.dy;
    var right = left;
    var bottom = top;
    for (final point in points.skip(1)) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fitToImage() {
    if (_viewport.isEmpty) {
      return;
    }
    final image = widget.data.imageSize;
    final scale = math.min(
      _viewport.width / image.width,
      _viewport.height / image.height,
    );
    _fitScale = scale;
    final dx = (_viewport.width - image.width * scale) / 2;
    final dy = (_viewport.height - image.height * scale) / 2;
    _controller.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _focusOnRect(Rect bounds) {
    if (_viewport.isEmpty) {
      return;
    }
    final padded = bounds.inflate(AppConfig.mapFitPadding);
    final scale = math
        .min(_viewport.width / padded.width, _viewport.height / padded.height)
        .clamp(_minScale, _maxScale);
    final tx = _viewport.width / 2 - padded.center.dx * scale;
    final ty = _viewport.height / 2 - padded.center.dy * scale;
    _controller.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  void _zoom(double factor) {
    if (_viewport.isEmpty) {
      return;
    }
    final current = _controller.value.getMaxScaleOnAxis();
    if (current <= 0) {
      return;
    }
    final target = (current * factor).clamp(_minScale, _maxScale);
    final applied = target / current;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final zoom = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    _controller.value = zoom * _controller.value;
  }

  void _handleTap(TapUpDetails details) {
    // Hit testing always happens in image space.
    final scene = _controller.toScene(details.localPosition);
    for (final building in widget.data.buildings.reversed) {
      if (building.contains(scene)) {
        widget.onBuildingTap?.call(building);
        return;
      }
    }
    widget.onMapTap?.call(scene);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final image = widget.data.imageSize;
        _fitScale = math.min(
          _viewport.width / image.width,
          _viewport.height / image.height,
        );

        if (!_didFit && !_viewport.isEmpty) {
          _didFit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _fitToImage();
            }
          });
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _handleTap,
                child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: SizedBox(
                    width: image.width,
                    height: image.height,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          AppConfig.mapImageAsset,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'Illustrated BiPSU Main Campus map',
                        ),
                        CustomPaint(
                          painter: CampusMapPainter(
                            buildings: widget.data.buildings,
                            roads: widget.data.roads,
                            selectedBuildingId: widget.selectedBuildingId,
                            routePoints: widget.routePoints,
                            showRoadGraph: _debugRoads,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapControl(
                    icon: Icons.add,
                    label: 'Zoom in',
                    onPressed: () => _zoom(1.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapControl(
                    icon: Icons.remove,
                    label: 'Zoom out',
                    onPressed: () => _zoom(1 / 1.4),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MapControl(
                    icon: Icons.crop_free,
                    label: 'Reset map view',
                    onPressed: _fitToImage,
                    onLongPress: () {
                      // Hidden debug overlay: draws the traced road graph.
                      setState(() => _debugRoads = !_debugRoads);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          onLongPress: onLongPress,
          child: SizedBox(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            child: Icon(icon, size: 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
