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
import 'horizontal_line_marker.dart';

class GHorizontalLineMarkerRender
    extends GOverlayMarkerRender<GHorizontalLineMarker, GOverlayMarkerTheme> {

  Rect? _lineRect;

  @override
  void doRenderMarker({
    required Canvas canvas,
    required GChart chart,
    required GPanel panel,
    required GComponent component,
    required GHorizontalLineMarker marker,
    required Rect area,
    required GOverlayMarkerTheme theme,
    required GPointViewPort pointViewPort,
    required GValueViewPort valueViewPort,
  }) {
    if (marker.keyCoordinates.isEmpty) {
      return;
    }

    final coordinate = marker.keyCoordinates.first;
    final position = coordinate.toPosition(
      area: area,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    // Clear previous control handles
    super.controlHandles.clear();

    // Calculate line bounds
    final double lineY = position.dy;
    final double startX = marker.extendAcrossChart ? area.left : area.left + 10;
    final double endX = marker.extendAcrossChart ? area.right : area.right - 10;

    // Store line rectangle for hit testing
    _lineRect = Rect.fromLTRB(
      startX,
      lineY - marker.thickness / 2,
      endX,
      lineY + marker.thickness / 2,
    );

    // Draw the horizontal line
    final linePath = Path();
    linePath.moveTo(startX, lineY);
    linePath.lineTo(endX, lineY);

    // Use marker's custom line style or fallback to theme
    final PaintStyle paintStyle = marker.lineStyle.copyWith(
      strokeColor: marker.color,
      strokeWidth: marker.thickness,
    );

    drawPath(
      canvas: canvas,
      path: linePath,
      style: paintStyle,
    );

    // Add control handles for interaction
    if (chart.hitTestEnable && marker.hitTestEnable) {
      // Central move handle
      super.controlHandles['move'] = GControlHandle(
        position: Offset((startX + endX) / 2, lineY),
        type: GControlHandleType.move,
        keyCoordinateIndex: 0,
      );

      // Left edge handle for visual reference
      if (!marker.extendAcrossChart) {
        super.controlHandles['left'] = GControlHandle(
          position: Offset(startX, lineY),
          type: GControlHandleType.view,
        );

        // Right edge handle for visual reference
        super.controlHandles['right'] = GControlHandle(
          position: Offset(endX, lineY),
          type: GControlHandleType.view,
        );
      }
    }

    // Draw control handles if marker is highlighted or selected
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

    // Draw value label if marker is highlighted
    if (marker.highlighted) {
      _drawValueLabel(
        canvas,
        marker,
        theme,
        Offset((startX + endX) / 2, lineY),
        area,
      );
    }
  }

  void _drawValueLabel(
      Canvas canvas,
      GHorizontalLineMarker marker,
      GOverlayMarkerTheme theme,
      Offset position,
      Rect area,
      ) {
    if (theme.labelStyle == null) return;

    final value = marker.value;
    final valueText = value.toStringAsFixed(2);

    // Create background for label
    final backgroundStyle = PaintStyle(
      fillColor: marker.color.withOpacity(0.8),
      strokeColor: marker.color,
      strokeWidth: 1.0,
    );

    drawText(
      canvas: canvas,
      text: valueText,
      anchor: Offset(area.right - 5, position.dy),
      defaultAlign: Alignment.centerRight,
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

    // Then check the line itself
    if (_lineRect != null) {
      final expandedRect = _lineRect!.inflate(epsilon ?? 5.0);
      return expandedRect.contains(position);
    }

    return false;
  }

}