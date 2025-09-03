import 'dart:ui';
import 'dart:math' as math;

import '../../components/marker/overlay_marker.dart';
import '../../components/marker/overlay_marker_render.dart';
import '../../style/paint_style.dart';
import '../../values/coord.dart';
import '../../values/value.dart';
import 'trend_line_marker_render.dart';

/// Trend line drawing tool with two interaction points
class GTrendLineMarker extends GOverlayMarker {
  /// Start point of the trend line
  GViewPortCoord get startPoint => keyCoordinates.first as GViewPortCoord;
  
  /// End point of the trend line
  GViewPortCoord get endPoint => keyCoordinates.last as GViewPortCoord;

  /// Color of the trend line
  final GValue<Color> _color;
  Color get color => _color.value;
  set color(Color value) => _color.value = value;

  /// Thickness of the trend line
  final GValue<double> _thickness;
  double get thickness => _thickness.value;
  set thickness(double value) => _thickness.value = value;

  /// Line style (solid, dashed, etc.)
  final GValue<PaintStyle> _lineStyle;
  PaintStyle get lineStyle => _lineStyle.value;
  set lineStyle(PaintStyle value) => _lineStyle.value = value;

  /// Whether to extend the line beyond the two points
  final GValue<bool> _extendLine;
  bool get extendLine => _extendLine.value;
  set extendLine(bool value) => _extendLine.value = value;

  /// Show slope/angle information
  final GValue<bool> _showInfo;
  bool get showInfo => _showInfo.value;
  set showInfo(bool value) => _showInfo.value = value;

  GTrendLineMarker({
    super.id,
    super.label,
    super.visible,
    super.layer,
    super.hitTestMode,
    super.theme,
    required GViewPortCoord startPoint,
    required GViewPortCoord endPoint,
    Color color = const Color(0xFFFF9800),
    double thickness = 1.5,
    PaintStyle? lineStyle,
    bool extendLine = false,
    bool showInfo = false,
    GOverlayMarkerRender? render,
    super.scaleHandler,
  }) : _color = GValue<Color>(color),
       _thickness = GValue<double>(thickness),
       _lineStyle = GValue<PaintStyle>(
         lineStyle ?? PaintStyle(
           strokeColor: color,
           strokeWidth: thickness,
         )
       ),
       _extendLine = GValue<bool>(extendLine),
       _showInfo = GValue<bool>(showInfo),
       super(keyCoordinates: [startPoint, endPoint]) {
    super.render = render ?? GTrendLineMarkerRender();
    
    // Update line style when color or thickness changes
    _color.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeColor: _color.value);
    });
    
    _thickness.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeWidth: _thickness.value);
    });
  }

  /// Update the start point of the trend line
  void updateStartPoint(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 1) {
      keyCoordinates[0] = newPoint;
    }
  }

  /// Update the end point of the trend line
  void updateEndPoint(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 2) {
      keyCoordinates[1] = newPoint;
    }
  }

  /// Calculate the slope of the trend line
  double get slope {
    if (keyCoordinates.length < 2) return 0.0;
    final start = startPoint;
    final end = endPoint;
    
    if (end.point == start.point) return double.infinity;
    
    return (end.value - start.value) / (end.point - start.point);
  }

  /// Calculate the angle of the trend line in degrees
  double get angleDegrees {
    if (keyCoordinates.length < 2) return 0.0;
    final start = startPoint;
    final end = endPoint;
    
    final deltaX = end.point - start.point;
    final deltaY = end.value - start.value;
    
    return (math.atan2(deltaY, deltaX) * 180 / math.pi);
  }

  /// Get the price change between start and end points
  double get priceChange {
    if (keyCoordinates.length < 2) return 0.0;
    return endPoint.value - startPoint.value;
  }

  /// Get the percentage change between start and end points
  double get percentageChange {
    if (keyCoordinates.length < 2) return 0.0;
    if (startPoint.value == 0) return 0.0;
    return ((endPoint.value - startPoint.value) / startPoint.value) * 100;
  }

  /// Create a trend line from two chart positions
  factory GTrendLineMarker.fromPositions({
    String? id,
    String? label,
    required double startPoint,
    required double startValue,
    required double endPoint,
    required double endValue,
    Color color = const Color(0xFFFF9800),
    double thickness = 1.5,
    bool extendLine = false,
    bool showInfo = false,
  }) {
    return GTrendLineMarker(
      id: id,
      label: label,
      startPoint: GViewPortCoord(point: startPoint, value: startValue),
      endPoint: GViewPortCoord(point: endPoint, value: endValue),
      color: color,
      thickness: thickness,
      extendLine: extendLine,
      showInfo: showInfo,
    );
  }
}

