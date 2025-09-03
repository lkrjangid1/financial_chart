import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../drawing_tools_manager.dart';
import 'drawing_tools_interaction_handler.dart';

/// Handles keyboard shortcuts for drawing tools
class GDrawingToolsKeyboardHandler {
  final GDrawingToolsInteractionHandler interactionHandler;
  final GDrawingToolsManager? drawingToolsManager;

  GDrawingToolsKeyboardHandler({
    required this.interactionHandler,
    this.drawingToolsManager,
  });

  /// Handle key events
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!interactionHandler.drawingToolsEnabled) return false;

    final isCtrlPressed = event.logicalKey == LogicalKeyboardKey.controlLeft ||
                         event.logicalKey == LogicalKeyboardKey.controlRight ||
                         HardwareKeyboard.instance.isControlPressed;
    
    final isShiftPressed = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                          event.logicalKey == LogicalKeyboardKey.shiftRight ||
                          HardwareKeyboard.instance.isShiftPressed;

    final isAltPressed = event.logicalKey == LogicalKeyboardKey.altLeft ||
                        event.logicalKey == LogicalKeyboardKey.altRight ||
                        HardwareKeyboard.instance.isAltPressed;

    // Handle specific key combinations
    if (isCtrlPressed) {
      return _handleCtrlKeyCombo(event.logicalKey);
    } else if (isShiftPressed) {
      return _handleShiftKeyCombo(event.logicalKey);
    } else if (isAltPressed) {
      return _handleAltKeyCombo(event.logicalKey);
    } else {
      return _handleSingleKey(event.logicalKey);
    }
  }

  bool _handleCtrlKeyCombo(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.keyZ:
        // Undo
        return interactionHandler.interactionState.undo();
      
      case LogicalKeyboardKey.keyY:
        // Redo
        return interactionHandler.interactionState.redo();
      
      case LogicalKeyboardKey.keyA:
        // Select all drawing tools
        _selectAllDrawingTools();
        return true;
      
      case LogicalKeyboardKey.keyD:
        // Duplicate selected tools
        _duplicateSelectedTools();
        return true;
      
      case LogicalKeyboardKey.keyC:
        // Copy selected tools (to clipboard/memory)
        _copySelectedTools();
        return true;
      
      case LogicalKeyboardKey.keyV:
        // Paste tools
        _pasteTools();
        return true;

      default:
        return false;
    }
  }

  bool _handleShiftKeyCombo(LogicalKeyboardKey key) {
    // Enable multi-selection mode while shift is pressed
    if (!interactionHandler.interactionState.multiSelectionEnabled) {
      interactionHandler.interactionState.setMultiSelectionEnabled(true);
    }

    switch (key) {
      case LogicalKeyboardKey.keyH:
        // Quick select horizontal line tool
        drawingToolsManager?.selectTool(DrawingToolType.horizontalLine);
        return true;
      
      case LogicalKeyboardKey.keyT:
        // Quick select trend line tool
        drawingToolsManager?.selectTool(DrawingToolType.trendLine);
        return true;
      
      case LogicalKeyboardKey.keyM:
        // Quick select measure tool
        drawingToolsManager?.selectTool(DrawingToolType.measure);
        return true;
      
      case LogicalKeyboardKey.keyR:
        // Quick select rectangle tool
        drawingToolsManager?.selectTool(DrawingToolType.rectangle);
        return true;

      default:
        return false;
    }
  }

  bool _handleAltKeyCombo(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.keyS:
        // Toggle snap mode
        final currentSnap = interactionHandler.interactionState.snapEnabled;
        interactionHandler.interactionState.setSnapEnabled(!currentSnap);
        return true;
      
      case LogicalKeyboardKey.keyG:
        // Toggle grid alignment
        final currentGrid = interactionHandler.interactionState.gridAlignmentEnabled;
        interactionHandler.interactionState.setGridAlignmentEnabled(!currentGrid);
        return true;

      default:
        return false;
    }
  }

  bool _handleSingleKey(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.escape:
        // Cancel current operation or clear selection
        if (drawingToolsManager?.isDrawingMode == true) {
          drawingToolsManager?.selectTool(null);
        } else if (interactionHandler.interactionState.hasSelection) {
          interactionHandler.interactionState.clearSelection();
        }
        return true;
      
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        // Delete selected tools
        _deleteSelectedTools();
        return true;
      
      case LogicalKeyboardKey.tab:
        // Cycle through selected tools or all tools
        _cycleSelection();
        return true;
      
      case LogicalKeyboardKey.enter:
        // Confirm current operation
        _confirmCurrentOperation();
        return true;
      
      case LogicalKeyboardKey.space:
        // Toggle drawing mode
        if (drawingToolsManager?.selectedTool != null) {
          drawingToolsManager?.selectTool(null);
        }
        return true;

      // Number keys for quick tool selection
      case LogicalKeyboardKey.digit1:
        drawingToolsManager?.selectTool(DrawingToolType.horizontalLine);
        return true;
      
      case LogicalKeyboardKey.digit2:
        drawingToolsManager?.selectTool(DrawingToolType.trendLine);
        return true;
      
      case LogicalKeyboardKey.digit3:
        drawingToolsManager?.selectTool(DrawingToolType.measure);
        return true;
      
      case LogicalKeyboardKey.digit4:
        drawingToolsManager?.selectTool(DrawingToolType.rectangle);
        return true;

      // Arrow keys for fine movement
      case LogicalKeyboardKey.arrowUp:
        _moveSelectedTools(0, -1);
        return true;
      
      case LogicalKeyboardKey.arrowDown:
        _moveSelectedTools(0, 1);
        return true;
      
      case LogicalKeyboardKey.arrowLeft:
        _moveSelectedTools(-1, 0);
        return true;
      
      case LogicalKeyboardKey.arrowRight:
        _moveSelectedTools(1, 0);
        return true;

      default:
        return false;
    }
  }

  void _selectAllDrawingTools() {
    if (drawingToolsManager == null) return;

    final allDrawingTools = drawingToolsManager!.getToolsByType<GOverlayMarker>()
        .where((marker) => marker is GHorizontalLineMarker ||
                          marker is GTrendLineMarker ||
                          marker is GMeasureMarker ||
                          marker is GRectangleMarker)
        .toList();

    interactionHandler.interactionState.clearSelection();
    for (final tool in allDrawingTools) {
      interactionHandler.interactionState.selectMarker(tool, clearOthers: false);
    }
  }

  void _duplicateSelectedTools() {
    final selectedMarkers = interactionHandler.interactionState.selectedMarkers;
    if (selectedMarkers.isEmpty || drawingToolsManager == null) return;

    for (final marker in selectedMarkers) {
      _duplicateMarker(marker);
    }
  }

  void _duplicateMarker(GOverlayMarker marker) {
    // Create a duplicate of the marker with slight offset
    GOverlayMarker? duplicate;

    if (marker is GHorizontalLineMarker) {
      duplicate = GHorizontalLineMarker(
        id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
        value: marker.value + 1.0, // Offset slightly
        color: marker.color,
        thickness: marker.thickness,
        extendAcrossChart: marker.extendAcrossChart,
      );
    } else if (marker is GTrendLineMarker) {
      final offsetStart = GViewPortCoord(
        point: marker.startPoint.point + 5,
        value: marker.startPoint.value + 1.0,
      );
      final offsetEnd = GViewPortCoord(
        point: marker.endPoint.point + 5,
        value: marker.endPoint.value + 1.0,
      );
      duplicate = GTrendLineMarker(
        id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
        startPoint: offsetStart,
        endPoint: offsetEnd,
        color: marker.color,
        thickness: marker.thickness,
        extendLine: marker.extendLine,
        showInfo: marker.showInfo,
      );
    } else if (marker is GMeasureMarker) {
      final offsetStart = GViewPortCoord(
        point: marker.startPoint.point + 5,
        value: marker.startPoint.value + 1.0,
      );
      final offsetEnd = GViewPortCoord(
        point: marker.endPoint.point + 5,
        value: marker.endPoint.value + 1.0,
      );
      duplicate = GMeasureMarker(
        id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
        startPoint: offsetStart,
        endPoint: offsetEnd,
        color: marker.color,
        thickness: marker.thickness,
        showInfo: marker.showInfo,
        showGrid: marker.showGrid,
      );
    } else if (marker is GRectangleMarker) {
      final offsetTopLeft = GViewPortCoord(
        point: marker.topLeft.point + 5,
        value: marker.topLeft.value + 1.0,
      );
      final offsetBottomRight = GViewPortCoord(
        point: marker.bottomRight.point + 5,
        value: marker.bottomRight.value + 1.0,
      );
      duplicate = GRectangleMarker(
        id: 'dup_${DateTime.now().millisecondsSinceEpoch}',
        topLeft: offsetTopLeft,
        bottomRight: offsetBottomRight,
        fillColor: marker.fillColor,
        borderColor: marker.borderColor,
        borderThickness: marker.borderThickness,
        fillOpacity: marker.fillOpacity,
        showDimensions: marker.showDimensions,
        cornerRadius: marker.cornerRadius,
      );
    }

    if (duplicate != null) {
      drawingToolsManager!.graph.addMarker(duplicate);
    }
  }

  void _copySelectedTools() {
    // Store selected tools in clipboard/memory for later paste
    // Implementation would store marker data for pasting
  }

  void _pasteTools() {
    // Paste previously copied tools
    // Implementation would recreate markers from stored data
  }

  void _deleteSelectedTools() {
    final selectedMarkers = interactionHandler.interactionState.selectedMarkers.toList();
    if (selectedMarkers.isEmpty || drawingToolsManager == null) return;

    for (final marker in selectedMarkers) {
      drawingToolsManager!.graph.removeMarker(marker);
    }

    interactionHandler.interactionState.clearSelection();
  }

  void _cycleSelection() {
    if (drawingToolsManager == null) return;

    final allDrawingTools = drawingToolsManager!.getToolsByType<GOverlayMarker>()
        .where((marker) => marker is GHorizontalLineMarker ||
                          marker is GTrendLineMarker ||
                          marker is GMeasureMarker ||
                          marker is GRectangleMarker)
        .toList();

    if (allDrawingTools.isEmpty) return;

    final currentSelection = interactionHandler.interactionState.selectedMarkers;
    
    if (currentSelection.isEmpty) {
      // Select first tool
      interactionHandler.interactionState.selectMarker(allDrawingTools.first);
    } else if (currentSelection.length == 1) {
      // Find current tool and select next
      final currentIndex = allDrawingTools.indexOf(currentSelection.first);
      final nextIndex = (currentIndex + 1) % allDrawingTools.length;
      interactionHandler.interactionState.selectMarker(allDrawingTools[nextIndex]);
    } else {
      // Multiple selection, clear and select first
      interactionHandler.interactionState.selectMarker(allDrawingTools.first);
    }
  }

  void _confirmCurrentOperation() {
    // Confirm current drawing operation or finish editing
    if (drawingToolsManager?.isDrawingMode == true) {
      drawingToolsManager?.selectTool(null);
    }
  }

  void _moveSelectedTools(double deltaX, double deltaY) {
    final selectedMarkers = interactionHandler.interactionState.selectedMarkers;
    if (selectedMarkers.isEmpty) return;

    // Fine movement with arrow keys
    const moveStep = 1.0;
    final actualDeltaX = deltaX * moveStep;
    final actualDeltaY = deltaY * moveStep;

    for (final marker in selectedMarkers) {
      _moveMarker(marker, actualDeltaX, actualDeltaY);
    }
  }

  void _moveMarker(GOverlayMarker marker, double deltaX, double deltaY) {
    // Move marker coordinates by delta amounts
    for (int i = 0; i < marker.keyCoordinates.length; i++) {
      final coord = marker.keyCoordinates[i];
      if (coord is GViewPortCoord) {
        marker.keyCoordinates[i] = GViewPortCoord(
          point: coord.point + deltaX,
          value: coord.value + deltaY,
        );
      }
    }
  }
}

/// Widget that handles keyboard events for drawing tools
class GDrawingToolsKeyboardListener extends StatefulWidget {
  final Widget child;
  final GDrawingToolsKeyboardHandler keyboardHandler;
  final bool autofocus;

  const GDrawingToolsKeyboardListener({
    Key? key,
    required this.child,
    required this.keyboardHandler,
    this.autofocus = true,
  }) : super(key: key);

  @override
  State<GDrawingToolsKeyboardListener> createState() => 
      _GDrawingToolsKeyboardListenerState();
}

class _GDrawingToolsKeyboardListenerState 
    extends State<GDrawingToolsKeyboardListener> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        final handled = widget.keyboardHandler.handleKeyEvent(event);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: widget.child,
      ),
    );
  }
}