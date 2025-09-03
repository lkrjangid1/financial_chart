import 'dart:ui';

import 'package:flutter/gestures.dart';

import '../chart.dart';
import '../components/components.dart';
import '../values/coord.dart';

/// Scale handler for drawing tools that provides interactive scaling/moving functionality
class GDrawingToolsScaleHandler<M extends GOverlayMarker> 
    extends GOverlayMarkerScaleHandler<M> {
  
  /// The marker being handled
  final M marker;
  
  /// The handle that was initially selected for the interaction
  String? _selectedHandle;
  
  /// Original coordinates at the start of interaction
  List<GCoordinate>? _originalCoordinates;
  
  /// Original position where the interaction started
  Offset? _startPosition;

  GDrawingToolsScaleHandler(this.marker);

  @override
  (GScaleUpdateCallback, GScaleEndCallback)? tryScale({
    required GChart chart,
    required GPanel panel,
    required GGraph graph,
    required M marker,
    required GPointViewPort pointViewPort,
    required GValueViewPort valueViewPort,
    required Rect area,
    required Offset position,
  }) {
    // Find which control handle was selected
    final render = marker.getRender();
    if (render is! GOverlayMarkerRender) return null;
    
    final overlayRender = render as GOverlayMarkerRender;
    
    // Check if any control handle was hit
    for (final handleEntry in overlayRender.controlHandles.entries) {
      final handle = handleEntry.value;
      final distance = (handle.position - position).distance;
      
      if (distance <= 10.0) { // Hit threshold
        _selectedHandle = handleEntry.key;
        _originalCoordinates = List.from(marker.keyCoordinates);
        _startPosition = position;
        
        return (
          ({required Offset position, required double scale, required double verticalScale}) =>
              _handleScaleUpdate(position, scale, verticalScale, pointViewPort, valueViewPort, area),
          (int pointerCount, double scaleVelocity, Velocity? velocity) =>
              _handleScaleEnd(pointerCount, scaleVelocity, velocity),
        );
      }
    }
    
    return null;
  }

  void _handleScaleUpdate(
    Offset position,
    double scale,
    double verticalScale,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area,
  ) {
    if (_selectedHandle == null || _originalCoordinates == null || _startPosition == null) {
      return;
    }

    final deltaX = position.dx - _startPosition!.dx;
    final deltaY = position.dy - _startPosition!.dy;

    switch (_selectedHandle) {
      case 'move':
      case 'middle':
      case 'center':
        _handleMove(deltaX, deltaY, pointViewPort, valueViewPort, area);
        break;
        
      case 'start':
      case 'top-left':
      case 'left':
        _handleResizeStart(position, pointViewPort, valueViewPort, area);
        break;
        
      case 'end':
      case 'bottom-right':
      case 'right':
        _handleResizeEnd(position, pointViewPort, valueViewPort, area);
        break;
        
      case 'top-right':
        _handleResizeCorner(position, pointViewPort, valueViewPort, area, isTopRight: true);
        break;
        
      case 'bottom-left':
        _handleResizeCorner(position, pointViewPort, valueViewPort, area, isBottomLeft: true);
        break;
        
      case 'top-center':
        _handleResizeSide(position, pointViewPort, valueViewPort, area, isTop: true);
        break;
        
      case 'bottom-center':
        _handleResizeSide(position, pointViewPort, valueViewPort, area, isBottom: true);
        break;
        
      case 'left-center':
        _handleResizeSide(position, pointViewPort, valueViewPort, area, isLeft: true);
        break;
        
      case 'right-center':
        _handleResizeSide(position, pointViewPort, valueViewPort, area, isRight: true);
        break;
    }
  }

  void _handleMove(
    double deltaX,
    double deltaY,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area,
  ) {
    for (int i = 0; i < marker.keyCoordinates.length; i++) {
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
        
        marker.keyCoordinates[i] = newCoord;
      }
    }
  }

  void _handleResizeStart(
    Offset position,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area,
  ) {
    if (marker.keyCoordinates.isNotEmpty) {
      final newCoord = GViewPortCoord.fromPosition(
        area: area,
        position: position,
        valueViewPort: valueViewPort,
        pointViewPort: pointViewPort,
      );
      marker.keyCoordinates[0] = newCoord;
    }
  }

  void _handleResizeEnd(
    Offset position,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area,
  ) {
    if (marker.keyCoordinates.length > 1) {
      final newCoord = GViewPortCoord.fromPosition(
        area: area,
        position: position,
        valueViewPort: valueViewPort,
        pointViewPort: pointViewPort,
      );
      marker.keyCoordinates[1] = newCoord;
    }
  }

  void _handleResizeCorner(
    Offset position,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area, {
    bool isTopRight = false,
    bool isBottomLeft = false,
  }) {
    if (marker.keyCoordinates.length >= 2) {
      final newCoord = GViewPortCoord.fromPosition(
        area: area,
        position: position,
        valueViewPort: valueViewPort,
        pointViewPort: pointViewPort,
      );
      
      if (isTopRight) {
        // Update top-right: modify first coord's value, second coord's point
        final topLeft = marker.keyCoordinates[0] as GViewPortCoord;
        final bottomRight = marker.keyCoordinates[1] as GViewPortCoord;
        
        marker.keyCoordinates[0] = GViewPortCoord(
          point: topLeft.point,
          value: newCoord.value,
        );
        marker.keyCoordinates[1] = GViewPortCoord(
          point: newCoord.point,
          value: bottomRight.value,
        );
      } else if (isBottomLeft) {
        // Update bottom-left: modify first coord's point, second coord's value
        final topLeft = marker.keyCoordinates[0] as GViewPortCoord;
        final bottomRight = marker.keyCoordinates[1] as GViewPortCoord;
        
        marker.keyCoordinates[0] = GViewPortCoord(
          point: newCoord.point,
          value: topLeft.value,
        );
        marker.keyCoordinates[1] = GViewPortCoord(
          point: bottomRight.point,
          value: newCoord.value,
        );
      }
    }
  }

  void _handleResizeSide(
    Offset position,
    GPointViewPort pointViewPort,
    GValueViewPort valueViewPort,
    Rect area, {
    bool isTop = false,
    bool isBottom = false,
    bool isLeft = false,
    bool isRight = false,
  }) {
    if (marker.keyCoordinates.length >= 2) {
      final newCoord = GViewPortCoord.fromPosition(
        area: area,
        position: position,
        valueViewPort: valueViewPort,
        pointViewPort: pointViewPort,
      );
      
      final topLeft = marker.keyCoordinates[0] as GViewPortCoord;
      final bottomRight = marker.keyCoordinates[1] as GViewPortCoord;
      
      if (isTop) {
        marker.keyCoordinates[0] = GViewPortCoord(
          point: topLeft.point,
          value: newCoord.value,
        );
      } else if (isBottom) {
        marker.keyCoordinates[1] = GViewPortCoord(
          point: bottomRight.point,
          value: newCoord.value,
        );
      } else if (isLeft) {
        marker.keyCoordinates[0] = GViewPortCoord(
          point: newCoord.point,
          value: topLeft.value,
        );
      } else if (isRight) {
        marker.keyCoordinates[1] = GViewPortCoord(
          point: newCoord.point,
          value: bottomRight.value,
        );
      }
    }
  }

  void _handleScaleEnd(int pointerCount, double scaleVelocity, Velocity? velocity) {
    // Clean up interaction state
    _selectedHandle = null;
    _originalCoordinates = null;
    _startPosition = null;
  }

  @override
  void scaleUpdate({
    required Offset position,
    required double scale,
    required double verticalScale,
  }) {
    // This method is called by the framework but we handle updates in _handleScaleUpdate
  }

  @override
  void scaleEnd(int pointerCount, double scaleVelocity, Velocity? velocity) {
    _handleScaleEnd(pointerCount, scaleVelocity, velocity);
  }
}