import 'dart:ui';
import 'dart:math' as math;

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
import 'trend_line_marker.dart';

class GTrendLineMarkerRender
    extends GOverlayMarkerRender<GTrendLineMarker, GOverlayMarkerTheme> {
  
  final List<Vector2> _hitTestPoints = [];

  @override
  void doRenderMarker({
    required Canvas canvas,
    required GChart chart,
    required GPanel panel,
    required GComponent component,
    required GTrendLineMarker marker,
    required Rect area,
    required GOverlayMarkerTheme theme,
    required GPointViewPort pointViewPort,
    required GValueViewPort valueViewPort,
  }) {
    if (marker.keyCoordinates.length < 2) {
      return;
    }

    final startPosition = marker.startPoint.toPosition(
      area: area,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    final endPosition = marker.endPoint.toPosition(
      area: area,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    // Clear previous state
    super.controlHandles.clear();
    _hitTestPoints.clear();

    // Calculate extended line if needed
    Offset lineStart = startPosition;
    Offset lineEnd = endPosition;

    if (marker.extendLine) {
      final extended = _calculateExtendedLine(
        startPosition,
        endPosition,
        area,
      );
      lineStart = extended.start;
      lineEnd = extended.end;
    }

    // Draw the trend line
    final linePath = Path();
    linePath.moveTo(lineStart.dx, lineStart.dy);
    linePath.lineTo(lineEnd.dx, lineEnd.dy);

    final paintStyle = marker.lineStyle.copyWith(
      strokeColor: marker.color,
      strokeWidth: marker.thickness,
    );

    drawPath(
      canvas: canvas,
      path: linePath,
      style: paintStyle,
    );

    // Store points for hit testing
    _hitTestPoints.add(lineStart.toVector2());
    _hitTestPoints.add(lineEnd.toVector2());

    // Add control handles for interaction
    if (chart.hitTestEnable && marker.hitTestEnable) {
      // Start point handle
      super.controlHandles['start'] = GControlHandle(
        position: startPosition,
        type: GControlHandleType.resize,
        keyCoordinateIndex: 0,
      );

      // End point handle
      super.controlHandles['end'] = GControlHandle(
        position: endPosition,
        type: GControlHandleType.resize,
        keyCoordinateIndex: 1,
      );

      // Middle point handle for moving the entire line
      final middlePosition = Offset(
        (startPosition.dx + endPosition.dx) / 2,
        (startPosition.dy + endPosition.dy) / 2,
      );
      
      super.controlHandles['middle'] = GControlHandle(
        position: middlePosition,
        type: GControlHandleType.move,
      );
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

    // Draw information overlay if enabled
    if (marker.showInfo && (marker.highlighted || marker.selected)) {
      _drawInfoOverlay(
        canvas,
        marker,
        theme,
        startPosition,
        endPosition,
        area,
      );
    }
  }

  ({Offset start, Offset end}) _calculateExtendedLine(
    Offset start,
    Offset end,
    Rect area,
  ) {
    // Calculate line direction
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    if (dx == 0) {
      // Vertical line
      return (
        start: Offset(start.dx, area.top),
        end: Offset(start.dx, area.bottom)
      );
    }

    final slope = dy / dx;
    final intercept = start.dy - slope * start.dx;

    // Calculate intersections with area boundaries
    final leftY = slope * area.left + intercept;
    final rightY = slope * area.right + intercept;
    final topX = (area.top - intercept) / slope;
    final bottomX = (area.bottom - intercept) / slope;

    // Find valid intersection points
    final intersections = <Offset>[];

    if (leftY >= area.top && leftY <= area.bottom) {
      intersections.add(Offset(area.left, leftY));
    }
    if (rightY >= area.top && rightY <= area.bottom) {
      intersections.add(Offset(area.right, rightY));
    }
    if (topX >= area.left && topX <= area.right) {
      intersections.add(Offset(topX, area.top));
    }
    if (bottomX >= area.left && bottomX <= area.right) {
      intersections.add(Offset(bottomX, area.bottom));
    }

    if (intersections.length >= 2) {
      return (start: intersections.first, end: intersections.last);
    }

    // Fallback to original points if no valid intersections
    return (start: start, end: end);
  }

  void _drawInfoOverlay(
    Canvas canvas,
    GTrendLineMarker marker,
    GOverlayMarkerTheme theme,
    Offset startPosition,
    Offset endPosition,
    Rect area,
  ) {
    if (theme.labelStyle == null) return;

    // Calculate info text
    final slope = marker.slope;
    final angle = marker.angleDegrees;
    final priceChange = marker.priceChange;
    final percentChange = marker.percentageChange;

    final infoText = [
      'Slope: ${slope.toStringAsFixed(4)}',
      'Angle: ${angle.toStringAsFixed(1)}°',
      'Change: ${priceChange >= 0 ? '+' : ''}${priceChange.toStringAsFixed(2)}',
      'Percent: ${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(2)}%',
    ].join('\n');

    // Position the info box
    final midPoint = Offset(
      (startPosition.dx + endPosition.dx) / 2,
      (startPosition.dy + endPosition.dy) / 2,
    );

    // Create background for info
    final backgroundStyle = PaintStyle(
      fillColor: marker.color.withOpacity(0.9),
      strokeColor: marker.color,
      strokeWidth: 1.0,
    );

    drawText(
      canvas: canvas,
      text: infoText,
      anchor: Offset(midPoint.dx, midPoint.dy - 30),
      defaultAlign: Alignment.center,
      style: theme.labelStyle!.copyWith(
        backgroundStyle: backgroundStyle,
        backgroundCornerRadius: 8.0,
      ),
    );
  }

  @override
  bool hitTest({required Offset position, double? epsilon}) {
    // First check control handles
    if (super.hitTestControlHandles(position: position, epsilon: epsilon)) {
      return true;
    }

    // Then check the line using polygon hit test
    if (_hitTestPoints.length >= 2) {
      return PolygonUtil.hitTest(
        vertices: _hitTestPoints,
        px: position.dx,
        py: position.dy,
        epsilon: epsilon ?? 8.0,
        testArea: false, // Only test the line, not the area
      );
    }

    return false;
  }
}