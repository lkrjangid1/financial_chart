import 'dart:ui';

import '../../components/marker/overlay_marker.dart';
import '../../components/marker/overlay_marker_render.dart';
import '../../style/paint_style.dart';
import '../../values/coord.dart';
import '../../values/value.dart';
import 'horizontal_line_marker_render.dart';

/// Horizontal line drawing tool that can be moved vertically and customized
class GHorizontalLineMarker extends GOverlayMarker {
  /// The value at which the horizontal line is drawn
  double get value => keyCoordinates.first.y;

  /// Color of the horizontal line
  final GValue<Color> _color;
  Color get color => _color.value;
  set color(Color value) => _color.value = value;

  /// Thickness of the horizontal line
  final GValue<double> _thickness;
  double get thickness => _thickness.value;
  set thickness(double value) => _thickness.value = value;

  /// Line style (solid, dashed, etc.)
  final GValue<PaintStyle> _lineStyle;
  PaintStyle get lineStyle => _lineStyle.value;
  set lineStyle(PaintStyle value) => _lineStyle.value = value;

  /// Whether to extend the line across the entire chart width
  final GValue<bool> _extendAcrossChart;
  bool get extendAcrossChart => _extendAcrossChart.value;
  set extendAcrossChart(bool value) => _extendAcrossChart.value = value;

  GHorizontalLineMarker({
    super.id,
    super.label,
    super.visible,
    super.layer,
    super.hitTestMode,
    super.theme,
    required double value,
    Color color = const Color(0xFF2196F3),
    double thickness = 1.0,
    PaintStyle? lineStyle,
    bool extendAcrossChart = true,
    GOverlayMarkerRender? render,
    super.scaleHandler,
  }) : _color = GValue<Color>(color),
        _thickness = GValue<double>(thickness),
        _lineStyle = GValue<PaintStyle>(
            lineStyle ?? PaintStyle(strokeColor: color, strokeWidth: thickness)
        ),
        _extendAcrossChart = GValue<bool>(extendAcrossChart),
        super(keyCoordinates: [
        GViewPortCoord(point: 0.0, value: value)
      ]) {
    super.render = render ?? GHorizontalLineMarkerRender();

    // Update line style when color or thickness changes
    _color.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeColor: _color.value);
    });

    _thickness.addListener(() {
      _lineStyle.value = _lineStyle.value.copyWith(strokeWidth: _thickness.value);
    });
  }

  /// Update the value (vertical position) of the horizontal line
  void updateValue(double newValue) {
    if (keyCoordinates.isNotEmpty && keyCoordinates.first is GViewPortCoord) {
      final coord = keyCoordinates.first as GViewPortCoord;
      final newCoord = coord.copyWith(value: newValue);
      keyCoordinates[0] = newCoord; // Update the coordinate in place

      // Notify listeners if needed (trigger repaint)
      // This ensures the visual update happens immediately
    }
  }

  /// Create a horizontal line from a position in the chart area
  factory GHorizontalLineMarker.fromPosition({
    String? id,
    String? label,
    required double positionY,
    required double chartValue,
    Color color = const Color(0xFF2196F3),
    double thickness = 1.0,
    PaintStyle? lineStyle,
    bool extendAcrossChart = true,
  }) {
    return GHorizontalLineMarker(
      id: id,
      label: label,
      value: chartValue,
      color: color,
      thickness: thickness,
      lineStyle: lineStyle,
      extendAcrossChart: extendAcrossChart,
    );
  }
}