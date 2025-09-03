import 'dart:ui';
import 'dart:math' as math;

import '../../components/marker/overlay_marker.dart';
import '../../components/marker/overlay_marker_render.dart';
import '../../style/paint_style.dart';
import '../../values/coord.dart';
import '../../values/value.dart';
import 'measure_marker_render.dart';

/// Measure tool for analyzing distance, price change, and time between two points
class GMeasureMarker extends GOverlayMarker {
  /// Start point of the measurement
  GViewPortCoord get startPoint => keyCoordinates.first as GViewPortCoord;
  
  /// End point of the measurement
  GViewPortCoord get endPoint => keyCoordinates.last as GViewPortCoord;

  /// Color of the measurement lines and text
  final GValue<Color> _color;
  Color get color => _color.value;
  set color(Color value) => _color.value = value;

  /// Thickness of the measurement lines
  final GValue<double> _thickness;
  double get thickness => _thickness.value;
  set thickness(double value) => _thickness.value = value;

  /// Line style for the measurement lines
  final GValue<PaintStyle> _lineStyle;
  PaintStyle get lineStyle => _lineStyle.value;
  set lineStyle(PaintStyle value) => _lineStyle.value = value;

  /// Whether to show the measurement info box
  final GValue<bool> _showInfo;
  bool get showInfo => _showInfo.value;
  set showInfo(bool value) => _showInfo.value = value;

  /// Whether to show grid lines (horizontal and vertical guides)
  final GValue<bool> _showGrid;
  bool get showGrid => _showGrid.value;
  set showGrid(bool value) => _showGrid.value = value;

  /// Format function for point values (e.g., time formatting)
  String Function(double point)? pointFormatter;

  /// Format function for value measurements (e.g., price formatting)
  String Function(double value)? valueFormatter;

  GMeasureMarker({
    super.id,
    super.label,
    super.visible,
    super.layer,
    super.hitTestMode,
    super.theme,
    required GViewPortCoord startPoint,
    required GViewPortCoord endPoint,
    Color color = const Color(0xFF9C27B0),
    double thickness = 1.0,
    PaintStyle? lineStyle,
    bool showInfo = true,
    bool showGrid = true,
    this.pointFormatter,
    this.valueFormatter,
    GOverlayMarkerRender? render,
    super.scaleHandler,
  }) : _color = GValue<Color>(color),
       _thickness = GValue<double>(thickness),
       _lineStyle = GValue<PaintStyle>(
         lineStyle ?? PaintStyle(
           strokeColor: color,
           strokeWidth: thickness,
           dash: [5.0, 5.0], // Dashed line by default
         )
       ),
       _showInfo = GValue<bool>(showInfo),
       _showGrid = GValue<bool>(showGrid),
       super(keyCoordinates: [startPoint, endPoint]) {
    super.render = render ?? GMeasureMarkerRender();
    
    // Update line style when color or thickness changes
    _color.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeColor: _color.value);
    });
    
    _thickness.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeWidth: _thickness.value);
    });
  }

  /// Calculate the horizontal distance between points
  double get horizontalDistance {
    if (keyCoordinates.length < 2) return 0.0;
    return (endPoint.point - startPoint.point).abs();
  }

  /// Calculate the vertical distance (price change) between points
  double get verticalDistance {
    if (keyCoordinates.length < 2) return 0.0;
    return endPoint.value - startPoint.value;
  }

  /// Calculate the diagonal distance between points
  double get diagonalDistance {
    if (keyCoordinates.length < 2) return 0.0;
    final dx = endPoint.point - startPoint.point;
    final dy = endPoint.value - startPoint.value;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Calculate the percentage change between points
  double get percentageChange {
    if (keyCoordinates.length < 2) return 0.0;
    if (startPoint.value == 0) return 0.0;
    return ((endPoint.value - startPoint.value) / startPoint.value) * 100;
  }

  /// Calculate the angle of the measurement line in degrees
  double get angleDegrees {
    if (keyCoordinates.length < 2) return 0.0;
    final dx = endPoint.point - startPoint.point;
    final dy = endPoint.value - startPoint.value;
    return math.atan2(dy, dx) * 180 / math.pi;
  }

  /// Get formatted measurement information
  String get measurementInfo {
    final hDist = horizontalDistance;
    final vDist = verticalDistance;
    final dDist = diagonalDistance;
    final pChange = percentageChange;
    final angle = angleDegrees;

    final pointText = pointFormatter?.call(hDist) ?? hDist.toStringAsFixed(2);
    final valueText = valueFormatter?.call(vDist) ?? vDist.toStringAsFixed(4);

    return [
      'Distance: ${dDist.toStringAsFixed(2)}',
      'Points: $pointText',
      'Value: $valueText',
      'Change: ${pChange >= 0 ? '+' : ''}${pChange.toStringAsFixed(2)}%',
      'Angle: ${angle.toStringAsFixed(1)}°',
    ].join('\n');
  }

  /// Update the start point of the measurement
  void updateStartPoint(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 1) {
      keyCoordinates[0] = newPoint;
    }
  }

  /// Update the end point of the measurement
  void updateEndPoint(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 2) {
      keyCoordinates[1] = newPoint;
    }
  }

  /// Create a measure tool from two chart positions
  factory GMeasureMarker.fromPositions({
    String? id,
    String? label,
    required double startPoint,
    required double startValue,
    required double endPoint,
    required double endValue,
    Color color = const Color(0xFF9C27B0),
    double thickness = 1.0,
    bool showInfo = true,
    bool showGrid = true,
    String Function(double point)? pointFormatter,
    String Function(double value)? valueFormatter,
  }) {
    return GMeasureMarker(
      id: id,
      label: label,
      startPoint: GViewPortCoord(point: startPoint, value: startValue),
      endPoint: GViewPortCoord(point: endPoint, value: endValue),
      color: color,
      thickness: thickness,
      showInfo: showInfo,
      showGrid: showGrid,
      pointFormatter: pointFormatter,
      valueFormatter: valueFormatter,
    );
  }
}