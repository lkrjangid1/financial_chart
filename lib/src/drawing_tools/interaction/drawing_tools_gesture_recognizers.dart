import 'package:flutter/gestures.dart';

import '../../chart.dart';
import '../../components/components.dart';
import '../drawing_tools.dart';

/// Custom scale gesture recognizer that prioritizes drawing tools interactions
class GDrawingToolsScaleGestureRecognizer extends ScaleGestureRecognizer {
  final GChart? chart;
  final bool Function()? isDrawingToolsEnabled;

  GDrawingToolsScaleGestureRecognizer({
    super.supportedDevices,
    this.chart,
    this.isDrawingToolsEnabled,
    super.dragStartBehavior = DragStartBehavior.down,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Reduce processing by limiting when we handle pointers
    if (!(isDrawingToolsEnabled?.call() ?? false)) {
      _addChartPointer(event);
      return;
    }

    // Quick check for drawing tools with early exit
    if (_shouldDrawingToolsHandlePointerOptimized(event)) {
      super.addAllowedPointer(event);
      return;
    }

    // Fall back to original chart interaction logic
    _addChartPointer(event);
  }

  bool _shouldDrawingToolsHandlePointerOptimized(PointerDownEvent event) {
    if (chart == null) return false;

    // Quick bounds check first
    bool inGraphArea = false;
    for (final panel in chart!.panels) {
      if (panel.graphArea().contains(event.localPosition)) {
        inGraphArea = true;
        break;
      }
    }

    if (!inGraphArea) return false;

    // Only check first few markers to prevent ANR
    int checkedMarkers = 0;
    const maxMarkersToCheck = 5;

    for (final panel in chart!.panels) {
      if (!panel.graphArea().contains(event.localPosition)) continue;

      for (final graph in panel.graphs) {
        for (final marker in graph.overlayMarkers) {
          if (checkedMarkers >= maxMarkersToCheck) return false;

          if (!_isDrawingToolMarker(marker) || !marker.visible) continue;
          checkedMarkers++;

          // Quick hit test with larger tolerance to reduce precision requirements
          if (marker.hitTest(position: event.localPosition, autoHighlight: false, epsilon: 15.0)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  void _addChartPointer(PointerDownEvent event) {
    // Replicate the original chart logic
    if (team?.captain != this) {
      team?.captain = this;
    }

    for (final panel in (chart?.panels ?? <GPanel>[])) {
      if (panel.resizable &&
          panel.splitterArea().contains(event.localPosition)) {
        super.addAllowedPointer(event);
        return;
      }
    }

    for (final panel in (chart?.panels ?? <GPanel>[])) {
      // scalable point axes allow scale
      for (final axis in panel.pointAxes) {
        if (panel.pointAxisAreaOf(axis).contains(event.localPosition) &&
            axis.scaleMode != GAxisScaleMode.none) {
          super.addAllowedPointer(event);
          return;
        }
      }
      // scalable value axes allow scale
      for (final axis in panel.valueAxes) {
        if (axis.scaleMode != GAxisScaleMode.none &&
            panel.valueAxisAreaOf(axis).contains(event.localPosition)) {
          super.addAllowedPointer(event);
          return;
        }
      }
    }

    // graph area allow scale when graphPanMode is not none
    for (final panel in (chart?.panels ?? <GPanel>[])) {
      if (panel.graphPanMode != GGraphPanMode.none &&
          panel.graphArea().contains(event.localPosition)) {
        super.addAllowedPointer(event);
        return;
      }
    }
  }

  bool _isDrawingToolMarker(GOverlayMarker marker) {
    return marker is GHorizontalLineMarker ||
        marker is GTrendLineMarker ||
        marker is GMeasureMarker ||
        marker is GRectangleMarker;
  }
}

/// Custom tap gesture recognizer for drawing tools
class GDrawingToolsTapGestureRecognizer extends TapGestureRecognizer {
  final GChart? chart;
  final bool Function()? isDrawingToolsEnabled;

  GDrawingToolsTapGestureRecognizer({
    super.supportedDevices,
    this.chart,
    this.isDrawingToolsEnabled,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (isDrawingToolsEnabled?.call() ?? false) {
      // Always allow tap events when drawing tools are enabled
      // This ensures we can handle tool creation and selection
      super.addAllowedPointer(event);
      return;
    }

    // Let the chart handle normal tap events
    super.addAllowedPointer(event);
  }
}

/// Custom long press gesture recognizer for drawing tools context menus
class GDrawingToolsLongPressGestureRecognizer extends LongPressGestureRecognizer {
  final GChart? chart;
  final bool Function()? isDrawingToolsEnabled;

  GDrawingToolsLongPressGestureRecognizer({
    super.supportedDevices,
    this.chart,
    this.isDrawingToolsEnabled,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (isDrawingToolsEnabled?.call() ?? false) {
      if (_hitTestDrawingTools(event.localPosition)) {
        super.addAllowedPointer(event);
        return;
      }
    }

    // Let parent handle if not a drawing tool
    super.addAllowedPointer(event);
  }

  bool _hitTestDrawingTools(Offset position) {
    if (chart == null) return false;

    for (final panel in chart!.panels) {
      if (!panel.graphArea().contains(position)) continue;

      for (final graph in panel.graphs) {
        for (final marker in graph.overlayMarkers) {
          if (_isDrawingToolMarker(marker) &&
              marker.visible &&
              marker.hitTest(position: position, autoHighlight: false)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _isDrawingToolMarker(GOverlayMarker marker) {
    return marker is GHorizontalLineMarker ||
        marker is GTrendLineMarker ||
        marker is GMeasureMarker ||
        marker is GRectangleMarker;
  }
}

/// Custom pan gesture recognizer for drawing tools creation
class GDrawingToolsPanGestureRecognizer extends PanGestureRecognizer {
  final GChart? chart;
  final bool Function()? isDrawingMode;

  GDrawingToolsPanGestureRecognizer({
    super.supportedDevices,
    this.chart,
    this.isDrawingMode,
  });

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (isDrawingMode?.call() ?? false) {
      // Allow pan events during drawing mode for tool creation
      final panel = _findPanelContaining(event.localPosition);
      if (panel != null && panel.graphArea().contains(event.localPosition)) {
        super.addAllowedPointer(event);
        return;
      }
    }
  }

  GPanel? _findPanelContaining(Offset position) {
    if (chart == null) return null;

    for (final panel in chart!.panels) {
      if (panel.panelArea().contains(position)) {
        return panel;
      }
    }

    return null;
  }
}