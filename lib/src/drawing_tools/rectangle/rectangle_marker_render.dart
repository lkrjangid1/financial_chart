import 'dart:ui';

import 'package:flutter/material.dart';

import '../../chart.dart';
import '../../components/component.dart';
import '../../components/marker/overlay_marker_render.dart';
import '../../components/marker/overlay_marker_theme.dart';
import '../../components/panel/panel.dart';
import '../../components/viewport_h.dart';
import '../../components/viewport_v.dart';
import '../../style/paint_style.dart';
import '../../vector/vectors.dart';
import 'rectangle_marker.dart';

class GRectangleMarkerRender
    extends GOverlayMarkerRender<GRectangleMarker, GOverlayMarkerTheme> {
  
  Rect? _rectangleRect;

  @override
  void doRenderMarker({
    required Canvas canvas,
    required GChart chart,
    required GPanel panel,
    required GComponent component,
    required GRectangleMarker marker,
    required Rect area,
    required GOverlayMarkerTheme theme,
    required GPointViewPort pointViewPort,
    required GValueViewPort valueViewPort,
  }) {
    if (marker.keyCoordinates.length < 2) {
      return;
    }

    // Get actual coordinates (normalized for proper drawing)
    final actualTopLeft = marker.actualTopLeft;
    final actualBottomRight = marker.actualBottomRight;

    final topLeftPosition = actualTopLeft.toPosition(
      area: area,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    final bottomRightPosition = actualBottomRight.toPosition(
      area: area,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    // Clear previous state
    super.controlHandles.clear();

    // Create rectangle bounds
    _rectangleRect = Rect.fromPoints(topLeftPosition, bottomRightPosition);

    // Draw the rectangle
    _drawRectangle(canvas, marker, _rectangleRect!);

    // Add control handles for interaction
    if (chart.hitTestEnable && marker.hitTestEnable) {
      _addControlHandles(marker, _rectangleRect!);
    }

    // Draw control handles if highlighted or selected
    if (marker.highlighted || marker.selected) {
      super.drawControlHandles(
        canvas: canvas,
        marker: marker,
        theme: theme,
        area: area,
        valueViewPort: valueViewPort,
        pointViewPort: pointViewPort,
      );
    }

    // Draw dimension labels if enabled
    if (marker.showDimensions && (marker.highlighted || marker.selected)) {
      _drawDimensionLabels(
        canvas,
        marker,
        theme,
        _rectangleRect!,
        area,
      );
    }
  }

  void _drawRectangle(Canvas canvas, GRectangleMarker marker, Rect rect) {
    final path = Path();
    
    if (marker.cornerRadius > 0) {
      // Rounded rectangle
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(marker.cornerRadius),
      );
      path.addRRect(rrect);
    } else {
      // Regular rectangle
      path.addRect(rect);
    }

    // Draw with the marker's paint style
    drawPath(
      canvas: canvas,
      path: path,
      style: marker.paintStyle,
    );
  }

  void _addControlHandles(GRectangleMarker marker, Rect rect) {
    // Corner handles
    super.controlHandles['top-left'] = GControlHandle(
      position: rect.topLeft,
      type: GControlHandleType.resize,
      keyCoordinateIndex: 0,
    );

    super.controlHandles['top-right'] = GControlHandle(
      position: rect.topRight,
      type: GControlHandleType.resize,
    );

    super.controlHandles['bottom-left'] = GControlHandle(
      position: rect.bottomLeft,
      type: GControlHandleType.resize,
    );

    super.controlHandles['bottom-right'] = GControlHandle(
      position: rect.bottomRight,
      type: GControlHandleType.resize,
      keyCoordinateIndex: 1,
    );

    // Side handles
    super.controlHandles['top-center'] = GControlHandle(
      position: Offset(rect.center.dx, rect.top),
      type: GControlHandleType.resize,
    );

    super.controlHandles['bottom-center'] = GControlHandle(
      position: Offset(rect.center.dx, rect.bottom),
      type: GControlHandleType.resize,
    );

    super.controlHandles['left-center'] = GControlHandle(
      position: Offset(rect.left, rect.center.dy),
      type: GControlHandleType.resize,
    );

    super.controlHandles['right-center'] = GControlHandle(
      position: Offset(rect.right, rect.center.dy),
      type: GControlHandleType.resize,
    );

    // Center handle for moving
    super.controlHandles['center'] = GControlHandle(
      position: rect.center,
      type: GControlHandleType.move,
    );
  }

  void _drawDimensionLabels(
    Canvas canvas,
    GRectangleMarker marker,
    GOverlayMarkerTheme theme,
    Rect rect,
    Rect area,
  ) {
    if (theme.labelStyle == null) return;

    final width = marker.width;
    final height = marker.height;
    final areaValue = marker.area;

    // Format dimension text
    final widthText = 'W: ${width.toStringAsFixed(2)}';
    final heightText = 'H: ${height.toStringAsFixed(2)}';
    final areaText = 'A: ${areaValue.toStringAsFixed(2)}';

    final dimensionInfo = [widthText, heightText, areaText].join('\n');

    // Position the dimension label
    final labelPosition = Offset(
      rect.center.dx,
      rect.top - 10,
    );

    // Create background for label
    final backgroundStyle = PaintStyle(
      fillColor: marker.borderColor.withOpacity(0.9),
      strokeColor: marker.borderColor,
      strokeWidth: 1.0,
    );

    drawText(
      canvas: canvas,
      text: dimensionInfo,
      anchor: labelPosition,
      defaultAlign: Alignment.bottomCenter,
      style: theme.labelStyle!.copyWith(
        backgroundStyle: backgroundStyle,
        backgroundCornerRadius: 4.0,
      ),
    );
  }

  @override
  bool hitTest({required Offset position, double? epsilon}) {
    // First check control handles
    if (super.hitTestControlHandles(position: position, epsilon: epsilon)) {
      return true;
    }

    // Then check if position is within the rectangle
    if (_rectangleRect != null) {
      // For filled rectangles, check if inside
      if (_rectangleRect!.contains(position)) {
        return true;
      }

      // For border-only rectangles, check if near the border
      final expandedRect = _rectangleRect!.inflate(epsilon ?? 5.0);
      final contractedRect = _rectangleRect!.deflate(epsilon ?? 5.0);
      
      return expandedRect.contains(position) && !contractedRect.contains(position);
    }

    return false;
  }
}