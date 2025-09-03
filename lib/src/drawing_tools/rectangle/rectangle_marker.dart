import 'dart:ui';
import 'dart:math' as math;

import '../../components/marker/overlay_marker.dart';
import '../../components/marker/overlay_marker_render.dart';
import '../../style/paint_style.dart';
import '../../values/coord.dart';
import '../../values/value.dart';
import 'rectangle_marker_render.dart';

/// Rectangle drawing tool for creating rectangular areas on the chart
class GRectangleMarker extends GOverlayMarker {
  /// Top-left corner of the rectangle
  GViewPortCoord get topLeft => keyCoordinates.first as GViewPortCoord;
  
  /// Bottom-right corner of the rectangle
  GViewPortCoord get bottomRight => keyCoordinates.last as GViewPortCoord;

  /// Fill color of the rectangle
  final GValue<Color?> _fillColor;
  Color? get fillColor => _fillColor.value;
  set fillColor(Color? value) => _fillColor.value = value;

  /// Border color of the rectangle
  final GValue<Color> _borderColor;
  Color get borderColor => _borderColor.value;
  set borderColor(Color value) => _borderColor.value = value;

  /// Border thickness of the rectangle
  final GValue<double> _borderThickness;
  double get borderThickness => _borderThickness.value;
  set borderThickness(double value) => _borderThickness.value = value;

  /// Opacity of the fill color
  final GValue<double> _fillOpacity;
  double get fillOpacity => _fillOpacity.value;
  set fillOpacity(double value) => _fillOpacity.value = value;

  /// Paint style for the rectangle
  final GValue<PaintStyle> _paintStyle;
  PaintStyle get paintStyle => _paintStyle.value;
  set paintStyle(PaintStyle value) => _paintStyle.value = value;

  /// Whether to show dimension labels
  final GValue<bool> _showDimensions;
  bool get showDimensions => _showDimensions.value;
  set showDimensions(bool value) => _showDimensions.value = value;

  /// Corner radius for rounded rectangles
  final GValue<double> _cornerRadius;
  double get cornerRadius => _cornerRadius.value;
  set cornerRadius(double value) => _cornerRadius.value = value;

  GRectangleMarker({
    super.id,
    super.label,
    super.visible,
    super.layer,
    super.hitTestMode,
    super.theme,
    required GViewPortCoord topLeft,
    required GViewPortCoord bottomRight,
    Color? fillColor,
    Color borderColor = const Color(0xFF4CAF50),
    double borderThickness = 1.5,
    double fillOpacity = 0.2,
    bool showDimensions = false,
    double cornerRadius = 0.0,
    PaintStyle? paintStyle,
    GOverlayMarkerRender? render,
    super.scaleHandler,
  }) : _fillColor = GValue<Color?>(fillColor),
       _borderColor = GValue<Color>(borderColor),
       _borderThickness = GValue<double>(borderThickness),
       _fillOpacity = GValue<double>(fillOpacity),
       _showDimensions = GValue<bool>(showDimensions),
       _cornerRadius = GValue<double>(cornerRadius),
       _paintStyle = GValue<PaintStyle>(
         paintStyle ?? _createDefaultPaintStyle(
           fillColor,
           borderColor,
           borderThickness,
           fillOpacity,
         )
       ),
       super(keyCoordinates: [topLeft, bottomRight]) {
    super.render = render ?? GRectangleMarkerRender();
    
    // Update paint style when properties change
    _fillColor.addListener(_updatePaintStyle);
    _borderColor.addListener(_updatePaintStyle);
    _borderThickness.addListener(_updatePaintStyle);
    _fillOpacity.addListener(_updatePaintStyle);
  }

  void _updatePaintStyle() {
    _paintStyle.value = _createDefaultPaintStyle(
      _fillColor.value,
      _borderColor.value,
      _borderThickness.value,
      _fillOpacity.value,
    );
  }

  static PaintStyle _createDefaultPaintStyle(
    Color? fillColor,
    Color borderColor,
    double borderThickness,
    double fillOpacity,
  ) {
    return PaintStyle(
      fillColor: fillColor?.withOpacity(fillOpacity),
      strokeColor: borderColor,
      strokeWidth: borderThickness,
    );
  }

  /// Calculate the width of the rectangle
  double get width {
    if (keyCoordinates.length < 2) return 0.0;
    return (bottomRight.point - topLeft.point).abs();
  }

  /// Calculate the height of the rectangle
  double get height {
    if (keyCoordinates.length < 2) return 0.0;
    return (topLeft.value - bottomRight.value).abs();
  }

  /// Calculate the area of the rectangle
  double get area {
    return width * height;
  }

  /// Get the center point of the rectangle
  GViewPortCoord get center {
    return GViewPortCoord(
      point: (topLeft.point + bottomRight.point) / 2,
      value: (topLeft.value + bottomRight.value) / 2,
    );
  }

  /// Update the top-left corner of the rectangle
  void updateTopLeft(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 1) {
      keyCoordinates[0] = newPoint;
    }
  }

  /// Update the bottom-right corner of the rectangle
  void updateBottomRight(GViewPortCoord newPoint) {
    if (keyCoordinates.length >= 2) {
      keyCoordinates[1] = newPoint;
    }
  }

  /// Get the actual top-left coordinate (accounting for user drawing direction)
  GViewPortCoord get actualTopLeft {
    if (keyCoordinates.length < 2) return topLeft;
    
    final minPoint = math.min(topLeft.point, bottomRight.point);
    final maxValue = math.max(topLeft.value, bottomRight.value);
    
    return GViewPortCoord(point: minPoint, value: maxValue);
  }

  /// Get the actual bottom-right coordinate (accounting for user drawing direction)
  GViewPortCoord get actualBottomRight {
    if (keyCoordinates.length < 2) return bottomRight;
    
    final maxPoint = math.max(topLeft.point, bottomRight.point);
    final minValue = math.min(topLeft.value, bottomRight.value);
    
    return GViewPortCoord(point: maxPoint, value: minValue);
  }

  /// Create a rectangle from normalized coordinates
  factory GRectangleMarker.fromBounds({
    String? id,
    String? label,
    required double leftPoint,
    required double topValue,
    required double rightPoint,
    required double bottomValue,
    Color? fillColor,
    Color borderColor = const Color(0xFF4CAF50),
    double borderThickness = 1.5,
    double fillOpacity = 0.2,
    bool showDimensions = false,
    double cornerRadius = 0.0,
  }) {
    return GRectangleMarker(
      id: id,
      label: label,
      topLeft: GViewPortCoord(point: leftPoint, value: topValue),
      bottomRight: GViewPortCoord(point: rightPoint, value: bottomValue),
      fillColor: fillColor,
      borderColor: borderColor,
      borderThickness: borderThickness,
      fillOpacity: fillOpacity,
      showDimensions: showDimensions,
      cornerRadius: cornerRadius,
    );
  }

  /// Create a square from center point and size
  factory GRectangleMarker.square({
    String? id,
    String? label,
    required GViewPortCoord center,
    required double size,
    Color? fillColor,
    Color borderColor = const Color(0xFF4CAF50),
    double borderThickness = 1.5,
    double fillOpacity = 0.2,
  }) {
    final halfSize = size / 2;
    return GRectangleMarker(
      id: id,
      label: label,
      topLeft: GViewPortCoord(
        point: center.point - halfSize,
        value: center.value + halfSize,
      ),
      bottomRight: GViewPortCoord(
        point: center.point + halfSize,
        value: center.value - halfSize,
      ),
      fillColor: fillColor,
      borderColor: borderColor,
      borderThickness: borderThickness,
      fillOpacity: fillOpacity,
    );
  }
}