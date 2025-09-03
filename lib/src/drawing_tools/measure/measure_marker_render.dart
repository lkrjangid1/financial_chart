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
import 'measure_marker.dart';

class GMeasureMarkerRender
    extends GOverlayMarkerRender<GMeasureMarker, GOverlayMarkerTheme> {
  
  final List<Vector2> _hitTestPoints = [];

  @override
  void doRenderMarker({
    required Canvas canvas,
    required GChart chart,
    required GPanel panel,
    required GComponent component,
    required GMeasureMarker marker,
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

    // Draw the measurement elements
    _drawMeasurementLines(canvas, marker, startPosition, endPosition);
    
    if (marker.showGrid) {
      _drawGridLines(canvas, marker, startPosition, endPosition, area);
    }

    // Store points for hit testing
    _hitTestPoints.add(startPosition.toVector2());
    _hitTestPoints.add(endPosition.toVector2());

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

      // Middle point handle for moving the entire measurement
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

    // Draw measurement info if enabled and marker is active
    if (marker.showInfo && (marker.highlighted || marker.selected)) {
      _drawMeasurementInfo(
        canvas,
        marker,
        theme,
        startPosition,
        endPosition,
        area,
      );
    }
  }

  void _drawMeasurementLines(
    Canvas canvas,
    GMeasureMarker marker,
    Offset startPosition,
    Offset endPosition,
  ) {
    // Main diagonal line
    final mainLinePath = Path();
    mainLinePath.moveTo(startPosition.dx, startPosition.dy);
    mainLinePath.lineTo(endPosition.dx, endPosition.dy);

    final paintStyle = marker.lineStyle.copyWith(
      strokeColor: marker.color,
      strokeWidth: marker.thickness,
    );

    drawPath(
      canvas: canvas,
      path: mainLinePath,
      style: paintStyle,
    );

    // Draw arrow heads at both ends
    _drawArrowHead(canvas, startPosition, endPosition, paintStyle);
    _drawArrowHead(canvas, endPosition, startPosition, paintStyle);
  }

  void _drawGridLines(
    Canvas canvas,
    GMeasureMarker marker,
    Offset startPosition,
    Offset endPosition,
    Rect area,
  ) {
    final gridStyle = marker.lineStyle.copyWith(
      strokeColor: marker.color.withOpacity(0.5),
      strokeWidth: marker.thickness * 0.5,
      dash: [3.0, 3.0], // Shorter dashes for grid
    );

    final gridPath = Path();

    // Horizontal lines
    gridPath.moveTo(startPosition.dx, startPosition.dy);
    gridPath.lineTo(endPosition.dx, startPosition.dy);
    
    gridPath.moveTo(endPosition.dx, startPosition.dy);
    gridPath.lineTo(endPosition.dx, endPosition.dy);

    // Vertical lines (if there's significant horizontal distance)
    if ((endPosition.dx - startPosition.dx).abs() > 20) {
      gridPath.moveTo(startPosition.dx, startPosition.dy);
      gridPath.lineTo(startPosition.dx, endPosition.dy);
      
      gridPath.moveTo(startPosition.dx, endPosition.dy);
      gridPath.lineTo(endPosition.dx, endPosition.dy);
    }

    drawPath(
      canvas: canvas,
      path: gridPath,
      style: gridStyle,
    );
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    PaintStyle paintStyle,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    
    if (length < 10) return; // Don't draw arrow heads for very short lines
    
    final unitX = dx / length;
    final unitY = dy / length;
    
    const arrowLength = 8.0;
    const arrowWidth = 4.0;
    
    final arrowTip = from;
    final arrowBase1 = Offset(
      arrowTip.dx + arrowLength * unitX - arrowWidth * unitY,
      arrowTip.dy + arrowLength * unitY + arrowWidth * unitX,
    );
    final arrowBase2 = Offset(
      arrowTip.dx + arrowLength * unitX + arrowWidth * unitY,
      arrowTip.dy + arrowLength * unitY - arrowWidth * unitX,
    );
    
    final arrowPath = Path();
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy);
    arrowPath.lineTo(arrowBase1.dx, arrowBase1.dy);
    arrowPath.lineTo(arrowBase2.dx, arrowBase2.dy);
    arrowPath.close();
    
    drawPath(
      canvas: canvas,
      path: arrowPath,
      style: paintStyle.copyWith(
        fillColor: paintStyle.strokeColor,
      ),
    );
  }

  void _drawMeasurementInfo(
    Canvas canvas,
    GMeasureMarker marker,
    GOverlayMarkerTheme theme,
    Offset startPosition,
    Offset endPosition,
    Rect area,
  ) {
    if (theme.labelStyle == null) return;

    // Position the info box away from the measurement line
    final midPoint = Offset(
      (startPosition.dx + endPosition.dx) / 2,
      (startPosition.dy + endPosition.dy) / 2,
    );

    // Calculate offset to avoid overlapping the line
    const offset = 40.0;
    final infoPosition = Offset(
      midPoint.dx + offset,
      midPoint.dy - offset,
    );

    // Ensure info box stays within chart area
    final clampedPosition = Offset(
      infoPosition.dx.clamp(area.left + 10, area.right - 150),
      infoPosition.dy.clamp(area.top + 10, area.bottom - 100),
    );

    // Create background for info
    final backgroundStyle = PaintStyle(
      fillColor: marker.color.withOpacity(0.9),
      strokeColor: marker.color,
      strokeWidth: 1.0,
    );

    drawText(
      canvas: canvas,
      text: marker.measurementInfo,
      anchor: clampedPosition,
      defaultAlign: Alignment.topLeft,
      style: theme.labelStyle!.copyWith(
        backgroundStyle: backgroundStyle,
        backgroundCornerRadius: 6.0,
      ),
    );
  }

  @override
  bool hitTest({required Offset position, double? epsilon}) {
    // First check control handles
    if (super.hitTestControlHandles(position: position, epsilon: epsilon)) {
      return true;
    }

    // Then check the measurement line using polygon hit test
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