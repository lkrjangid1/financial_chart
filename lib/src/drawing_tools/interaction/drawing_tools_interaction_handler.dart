import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chart.dart';
import '../../chart_interaction.dart';
import '../../components/components.dart';
import '../../values/coord.dart';
import '../drawing_tools.dart';
import '../drawing_tools_manager.dart';
import 'drawing_tools_interaction_state.dart';

/// Enhanced interaction handler that integrates drawing tools with existing chart functionality
class GDrawingToolsInteractionHandler extends GChartInteractionHandler {
  /// Reference to the chart (exposed from private _chart in parent)
  GChart? _chartRef;

  /// Drawing tools manager for handling tool creation and management
  GDrawingToolsManager? drawingToolsManager;

  /// Current interaction state for drawing tools
  final GDrawingToolsInteractionState _interactionState = GDrawingToolsInteractionState();

  /// Whether drawing tools are currently enabled
  bool _drawingToolsEnabled = false;

  /// Currently selected drawing tool marker for manipulation
  GOverlayMarker? _selectedMarker;

  /// The control handle being manipulated
  String? _selectedHandle;

  /// Original position where interaction started
  Offset? _startPosition;

  /// Original coordinates before interaction
  List<GCoordinate>? _originalCoordinates;

  /// Throttling for hover events to improve performance
  DateTime _lastHoverTime = DateTime.now();
  static const Duration _hoverThrottleDuration = Duration(milliseconds: 16); // ~60fps

  /// Get the current interaction state
  GDrawingToolsInteractionState get interactionState => _interactionState;

  /// Check if drawing tools are enabled
  bool get drawingToolsEnabled => _drawingToolsEnabled;

  /// Get the currently selected marker
  GOverlayMarker? get selectedMarker => _selectedMarker;

  /// Get the chart reference
  GChart? get chart => _chartRef;

  @override
  void attach(GChart chart) {
    super.attach(chart);
    _chartRef = chart; // Store our own reference
  }

  /// Enable or disable drawing tools interaction
  void setDrawingToolsEnabled(bool enabled) {
    _drawingToolsEnabled = enabled;
    if (!enabled) {
      _clearInteractionState();
    }
  }

  /// Set the drawing tools manager
  void setDrawingToolsManager(GDrawingToolsManager? manager) {
    drawingToolsManager = manager;
  }

  @override
  void mouseEnter({required Offset position}) {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      _handleDrawingToolsMouseEnter(position);
    }
    super.mouseEnter(position: position);
  }

  @override
  void mouseExit() {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      _handleDrawingToolsMouseExit();
    }
    super.mouseExit();
  }

  @override
  void mouseHover({required Offset position}) {
    // Throttle hover events to improve performance
    final now = DateTime.now();
    if (now.difference(_lastHoverTime) < _hoverThrottleDuration) {
      return;
    }
    _lastHoverTime = now;

    if (_drawingToolsEnabled && drawingToolsManager != null) {
      _handleDrawingToolsMouseHover(position);
    }
    super.mouseHover(position: position);
  }

  @override
  void tapDown({required Offset position, required bool isTouch}) {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      final handled = _handleDrawingToolsTapDown(position);
      if (handled) return;
    }
    super.tapDown(position: position, isTouch: isTouch);
  }

  @override
  void tapUp() {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      final handled = _handleDrawingToolsTapUp();
      if (handled) return;
    }
    super.tapUp();
  }

  @override
  void scaleStart({required Offset start, required int pointerCount}) {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      final handled = _handleDrawingToolsScaleStart(start, pointerCount);
      if (handled) return;
    }
    super.scaleStart(start: start, pointerCount: pointerCount);
  }

  @override
  void scaleUpdate({
    required Offset position,
    required double scale,
    required double verticalScale,
  }) {
    if (_drawingToolsEnabled && _interactionState.isActive) {
      _handleDrawingToolsScaleUpdate(position, scale, verticalScale);
      return;
    }
    super.scaleUpdate(
      position: position,
      scale: scale,
      verticalScale: verticalScale,
    );
  }

  @override
  void scaleEnd(int pointerCount, double scaleVelocity, Velocity velocity) {
    if (_drawingToolsEnabled && _interactionState.isActive) {
      _handleDrawingToolsScaleEnd(pointerCount, scaleVelocity, velocity);
      return;
    }
    super.scaleEnd(pointerCount, scaleVelocity, velocity);
  }

  @override
  void longPressStart({required Offset position}) {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      final handled = _handleDrawingToolsLongPress(position);
      if (handled) return;
    }
    super.longPressStart(position: position);
  }

  @override
  void doubleTap({required Offset position}) {
    if (_drawingToolsEnabled && drawingToolsManager != null) {
      final handled = _handleDrawingToolsDoubleTap(position);
      if (handled) return;
    }
    super.doubleTap(position: position);
  }

  // ========== Drawing Tools Specific Event Handlers ==========

  void _handleDrawingToolsMouseEnter(Offset position) {
    // Handle drawing tools specific mouse enter logic
    if (_chartRef != null) {
      _chartRef!.crosshair.updateCrossPosition(
        chart: _chartRef!,
        x: position.dx,
        y: position.dy,
        trigger: GCrosshairTrigger.mouseEnter,
      );
    }
  }

  void _handleDrawingToolsMouseExit() {
    // Clear any drawing tools highlighting
    _clearMarkerHighlighting();

    if (_chartRef != null) {
      _chartRef!.crosshair.updateCrossPosition(
        chart: _chartRef!,
        trigger: GCrosshairTrigger.mouseExit,
      );
    }
  }

  void _handleDrawingToolsMouseHover(Offset position) {
    // Skip hover processing if interaction is active to reduce load
    if (_interactionState.isActive) return;

    // Clear previous highlighting with minimal processing
    _clearMarkerHighlighting();

    // Find marker under cursor with early exit optimizations
    final hitResult = _hitTestDrawingToolsOptimized(position);
    if (hitResult.marker != null) {
      hitResult.marker!.highlighted = true;

      // Update mouse cursor based on interaction type
      if (hitResult.handle != null) {
        _chartRef?.mouseCursor.value = _getCursorForHandle(hitResult.handle!);
      } else {
        _chartRef?.mouseCursor.value = SystemMouseCursors.move;
      }
    } else if (drawingToolsManager!.isDrawingMode) {
      _chartRef?.mouseCursor.value = SystemMouseCursors.precise;
    }
  }

  bool _handleDrawingToolsTapDown(Offset position) {
    final hitResult = _hitTestDrawingToolsOptimized(position);

    // Check if we're in drawing mode
    if (drawingToolsManager!.isDrawingMode) {
      drawingToolsManager!.handlePointerDown(position);
      return true;
    }

    // Check if we hit a drawing tool
    if (hitResult.marker != null) {
      _selectMarker(hitResult.marker!, hitResult.handle, position);
      return true;
    }

    // Clear selection if clicking empty space
    _clearSelection();
    return false;
  }

  bool _handleDrawingToolsTapUp() {
    if (drawingToolsManager!.isDrawingMode) {
      drawingToolsManager!.handlePointerUp(Offset.zero);
      return true;
    }
    return false;
  }

  bool _handleDrawingToolsScaleStart(Offset start, int pointerCount) {
    if (drawingToolsManager!.isDrawingMode) {
      return false; // Let drawing mode handle this
    }

    final hitResult = _hitTestDrawingToolsOptimized(start);
    if (hitResult.marker != null) {
      _startInteraction(hitResult.marker!, hitResult.handle, start);
      return true;
    }

    return false;
  }

  void _handleDrawingToolsScaleUpdate(
      Offset position,
      double scale,
      double verticalScale,
      ) {
    if (drawingToolsManager!.isDrawingMode) {
      drawingToolsManager!.handlePointerMove(position);
      return;
    }

    if (_interactionState.mode == GDrawingToolsInteractionMode.manipulating &&
        _selectedMarker != null) {
      _updateMarkerPosition(position, scale, verticalScale);
    }
  }

  void _handleDrawingToolsScaleEnd(
      int pointerCount,
      double scaleVelocity,
      Velocity velocity,
      ) {
    if (_interactionState.isActive) {
      _endInteraction();
    }
  }

  bool _handleDrawingToolsLongPress(Offset position) {
    final hitResult = _hitTestDrawingToolsOptimized(position);
    if (hitResult.marker != null) {
      _showContextMenu(hitResult.marker!, position);
      return true;
    }
    return false;
  }

  bool _handleDrawingToolsDoubleTap(Offset position) {
    final hitResult = _hitTestDrawingToolsOptimized(position);
    if (hitResult.marker != null) {
      _showPropertiesDialog(hitResult.marker!);
      return true;
    }
    return false;
  }

  // ========== Hit Testing and Marker Management ==========

  /// Optimized hit testing that exits early and reduces processing
  GDrawingToolHitResult _hitTestDrawingToolsOptimized(Offset position) {
    if (_chartRef == null) {
      return GDrawingToolHitResult(marker: null, handle: null, position: position);
    }

    // Limit hit testing to reduce ANR risk
    int testedMarkers = 0;
    const maxMarkersToTest = 10; // Limit to prevent blocking

    for (final panel in _chartRef!.panels) {
      if (!panel.graphArea().contains(position)) continue;

      for (final graph in panel.graphs) {
        // Test overlay markers in reverse order (top to bottom) with limit
        for (int i = graph.overlayMarkers.length - 1; i >= 0 && testedMarkers < maxMarkersToTest; i--) {
          final marker = graph.overlayMarkers[i];

          // Only test drawing tool markers
          if (!_isDrawingToolMarker(marker)) continue;
          if (!marker.visible) continue;

          testedMarkers++;

          // Test control handles first with reduced sensitivity
          final render = marker.getRender();
          if (render is GOverlayMarkerRender) {
            final overlayRender = render as GOverlayMarkerRender;

            for (final handleEntry in overlayRender.controlHandles.entries) {
              final handle = handleEntry.value;
              final distance = (handle.position - position).distance;

              if (distance <= _interactionState.interactionSensitivity) {
                return GDrawingToolHitResult(
                  marker: marker,
                  handle: handleEntry.key,
                  position: position,
                );
              }
            }
          }

          // Test marker body with reduced sensitivity
          if (marker.hitTest(position: position, autoHighlight: false, epsilon: _interactionState.interactionSensitivity)) {
            return GDrawingToolHitResult(
              marker: marker,
              handle: null,
              position: position,
            );
          }
        }
      }
    }

    return GDrawingToolHitResult(marker: null, handle: null, position: position);
  }

  bool _isDrawingToolMarker(GOverlayMarker marker) {
    return marker is GHorizontalLineMarker ||
        marker is GTrendLineMarker ||
        marker is GMeasureMarker ||
        marker is GRectangleMarker;
  }

  SystemMouseCursor _getCursorForHandle(String handleType) {
    // Special handling for horizontal line move cursor
    if (_selectedMarker is GHorizontalLineMarker && handleType == 'move') {
      return SystemMouseCursors.resizeUpDown; // Vertical resize cursor for horizontal lines
    }

    switch (handleType) {
      case 'move':
      case 'middle':
      case 'center':
        return SystemMouseCursors.move;
      case 'start':
      case 'end':
      case 'top-left':
      case 'bottom-right':
        return SystemMouseCursors.resizeUpLeftDownRight;
      case 'top-right':
      case 'bottom-left':
        return SystemMouseCursors.resizeUpRightDownLeft;
      case 'top-center':
      case 'bottom-center':
        return SystemMouseCursors.resizeUpDown;
      case 'left-center':
      case 'right-center':
        return SystemMouseCursors.resizeLeftRight;
      default:
        return SystemMouseCursors.grab;
    }
  }

  // ========== Marker Selection and Manipulation ==========

  void _selectMarker(GOverlayMarker marker, String? handle, Offset position) {
    _clearSelection();
    _selectedMarker = marker;
    _selectedHandle = handle;
    _startPosition = position;

    marker.selected = true;
    _interactionState.setMode(GDrawingToolsInteractionMode.selected);
    _interactionState.selectMarker(marker);
  }

  void _startInteraction(GOverlayMarker marker, String? handle, Offset position) {
    _selectedMarker = marker;
    _selectedHandle = handle;
    _startPosition = position;
    _originalCoordinates = List.from(marker.keyCoordinates);

    marker.selected = true;
    _interactionState.setMode(GDrawingToolsInteractionMode.manipulating);
    _interactionState.setActiveMarker(marker);
    _interactionState.setActiveHandle(handle);
    _interactionState.setStartPosition(position);
  }

  void _updateMarkerPosition(Offset position, double scale, double verticalScale) {
    if (_selectedMarker == null || _startPosition == null || _originalCoordinates == null || _chartRef == null) {
      return;
    }

    final panel = _findPanelForMarker(_selectedMarker!);
    if (panel == null) return;

    final pointViewPort = _chartRef!.pointViewPort;
    final valueViewPort = panel.findValueViewPortById(
        _findGraphForMarker(_selectedMarker!)?.valueViewPortId ?? ''
    );
    final area = panel.graphArea();

    final deltaX = position.dx - _startPosition!.dx;
    final deltaY = position.dy - _startPosition!.dy;

    if (_selectedHandle == null ||
        _selectedHandle == 'move' ||
        _selectedHandle == 'middle' ||
        _selectedHandle == 'center') {
      // Move entire marker
      _moveMarker(deltaX, deltaY, pointViewPort, valueViewPort, area);
    } else {
      // Resize/reshape marker
      _resizeMarker(position, pointViewPort, valueViewPort, area);
    }

    _interactionState.setCurrentPosition(position);
  }

  void _moveMarker(
      double deltaX,
      double deltaY,
      GPointViewPort pointViewPort,
      GValueViewPort valueViewPort,
      Rect area,
      ) {
    if (_selectedMarker == null || _originalCoordinates == null) return;

    for (int i = 0; i < _selectedMarker!.keyCoordinates.length; i++) {
      final originalCoord = _originalCoordinates![i];
      if (originalCoord is GViewPortCoord) {
        final originalPosition = originalCoord.toPosition(
          area: area,
          valueViewPort: valueViewPort,
          pointViewPort: pointViewPort,
        );

        final newPosition = Offset(
          originalPosition.dx + deltaX,
          originalPosition.dy + deltaY,
        );

        final newCoord = GViewPortCoord.fromPosition(
          area: area,
          position: newPosition,
          valueViewPort: valueViewPort,
          pointViewPort: pointViewPort,
        );

        _selectedMarker!.keyCoordinates[i] = newCoord;
      }
    }
  }

  void _resizeMarker(
      Offset position,
      GPointViewPort pointViewPort,
      GValueViewPort valueViewPort,
      Rect area,
      ) {
    if (_selectedMarker == null || _selectedHandle == null) return;

    final newCoord = GViewPortCoord.fromPosition(
      area: area,
      position: position,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );

    // Handle different resize operations based on handle type
    switch (_selectedHandle!) {
      case 'start':
        if (_selectedMarker!.keyCoordinates.isNotEmpty) {
          _selectedMarker!.keyCoordinates[0] = newCoord;
        }
        break;
      case 'end':
        if (_selectedMarker!.keyCoordinates.length > 1) {
          _selectedMarker!.keyCoordinates[1] = newCoord;
        }
        break;
      default:
        _handleSpecificResize(newCoord);
    }
  }

  void _handleSpecificResize(GViewPortCoord newCoord) {
    // Handle marker-specific resize logic
    if (_selectedMarker is GHorizontalLineMarker) {
      final hLine = _selectedMarker as GHorizontalLineMarker;
      hLine.updateValue(newCoord.value);
    }
    // Add more marker-specific handling as needed
  }

  void _endInteraction() {
    // Record action for undo/redo if coordinates changed
    if (_selectedMarker != null && _originalCoordinates != null) {
      final currentCoordinates = List.from(_selectedMarker!.keyCoordinates);
      _interactionState.recordAction(
        GMoveMarkerAction(
          marker: _selectedMarker!,
          originalCoordinates: _originalCoordinates!,
          newCoordinates: currentCoordinates,
        ),
      );
    }

    _interactionState.setMode(GDrawingToolsInteractionMode.idle);
    _interactionState.setActiveMarker(null);
    _interactionState.setActiveHandle(null);
    _interactionState.setStartPosition(null);
    _interactionState.setCurrentPosition(null);

    _selectedHandle = null;
    _startPosition = null;
    _originalCoordinates = null;

    // Keep marker selected for further operations
  }

  void _clearSelection() {
    if (_selectedMarker != null) {
      _selectedMarker!.selected = false;
      _selectedMarker = null;
    }
    _interactionState.clearSelection();
    _interactionState.setMode(GDrawingToolsInteractionMode.idle);
    _interactionState.setActiveMarker(null);
    _interactionState.setActiveHandle(null);
    _interactionState.setStartPosition(null);
    _interactionState.setCurrentPosition(null);
  }

  void _clearMarkerHighlighting() {
    if (_chartRef == null) return;

    // Optimized highlighting clear - only process visible markers
    for (final panel in _chartRef!.panels) {
      for (final graph in panel.graphs) {
        for (final marker in graph.overlayMarkers) {
          if (_isDrawingToolMarker(marker) &&
              marker.highlighted &&
              marker != _selectedMarker &&
              marker.visible) {
            marker.highlighted = false;
          }
        }
      }
    }
  }

  void _clearInteractionState() {
    _clearSelection();
    _clearMarkerHighlighting();
    _interactionState.reset();
  }

  // ========== Context Menu and Properties ==========

  void _showContextMenu(GOverlayMarker marker, Offset position) {
    // Implementation would show context menu with options like:
    // - Delete
    // - Properties
    // - Duplicate
    // - Change color/style
    debugPrint('Context menu for marker: ${marker.id}');
  }

  void _showPropertiesDialog(GOverlayMarker marker) {
    // Implementation would show properties dialog
    debugPrint('Properties dialog for marker: ${marker.id}');
  }

  // ========== Helper Methods ==========

  GPanel? _findPanelForMarker(GOverlayMarker marker) {
    if (_chartRef == null) return null;

    for (final panel in _chartRef!.panels) {
      for (final graph in panel.graphs) {
        if (graph.overlayMarkers.contains(marker)) {
          return panel;
        }
      }
    }
    return null;
  }

  GGraph? _findGraphForMarker(GOverlayMarker marker) {
    if (_chartRef == null) return null;

    for (final panel in _chartRef!.panels) {
      for (final graph in panel.graphs) {
        if (graph.overlayMarkers.contains(marker)) {
          return graph;
        }
      }
    }
    return null;
  }
}

/// Result of hit testing drawing tools
class GDrawingToolHitResult {
  final GOverlayMarker? marker;
  final String? handle;
  final Offset position;

  const GDrawingToolHitResult({
    required this.marker,
    required this.handle,
    required this.position,
  });
}