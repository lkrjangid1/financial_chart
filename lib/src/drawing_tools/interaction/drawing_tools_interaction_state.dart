import 'dart:ui';

import '../../components/marker/overlay_marker.dart';
import '../../values/value.dart';

/// Modes of interaction for drawing tools
enum GDrawingToolsInteractionMode {
  /// No active interaction
  idle,
  
  /// Drawing a new tool
  drawing,
  
  /// A tool is selected but not being manipulated
  selected,
  
  /// Actively manipulating a selected tool
  manipulating,
  
  /// Showing context menu
  contextMenu,
  
  /// In properties editing mode
  properties,
}

/// State management for drawing tools interactions
class GDrawingToolsInteractionState {
  /// Current interaction mode
  final GValue<GDrawingToolsInteractionMode> _mode = 
      GValue<GDrawingToolsInteractionMode>(GDrawingToolsInteractionMode.idle);

  /// Currently active marker being manipulated
  final GValue<GOverlayMarker?> _activeMarker = GValue<GOverlayMarker?>(null);

  /// The handle being manipulated (if any)
  final GValue<String?> _activeHandle = GValue<String?>(null);

  /// Start position of current interaction
  final GValue<Offset?> _startPosition = GValue<Offset?>(null);

  /// Current position during interaction
  final GValue<Offset?> _currentPosition = GValue<Offset?>(null);

  /// Whether snapping is enabled
  final GValue<bool> _snapEnabled = GValue<bool>(true);

  /// Snap tolerance in pixels
  final GValue<double> _snapTolerance = GValue<double>(10.0);

  /// Whether grid alignment is enabled
  final GValue<bool> _gridAlignmentEnabled = GValue<bool>(false);

  /// Grid size for alignment
  final GValue<double> _gridSize = GValue<double>(20.0);

  /// Interaction sensitivity (how close cursor must be to activate)
  final GValue<double> _interactionSensitivity = GValue<double>(8.0);

  /// Whether multi-selection is enabled
  final GValue<bool> _multiSelectionEnabled = GValue<bool>(false);

  /// List of currently selected markers
  final List<GOverlayMarker> _selectedMarkers = [];

  /// History of actions for undo/redo
  final List<GDrawingToolsAction> _actionHistory = [];

  /// Current position in action history
  int _historyPosition = -1;

  // Getters
  GDrawingToolsInteractionMode get mode => _mode.value;
  GOverlayMarker? get activeMarker => _activeMarker.value;
  String? get activeHandle => _activeHandle.value;
  Offset? get startPosition => _startPosition.value;
  Offset? get currentPosition => _currentPosition.value;
  bool get snapEnabled => _snapEnabled.value;
  double get snapTolerance => _snapTolerance.value;
  bool get gridAlignmentEnabled => _gridAlignmentEnabled.value;
  double get gridSize => _gridSize.value;
  double get interactionSensitivity => _interactionSensitivity.value;
  bool get multiSelectionEnabled => _multiSelectionEnabled.value;
  List<GOverlayMarker> get selectedMarkers => List.unmodifiable(_selectedMarkers);

  /// Check if currently in an active interaction
  bool get isActive => mode != GDrawingToolsInteractionMode.idle;

  /// Check if currently drawing
  bool get isDrawing => mode == GDrawingToolsInteractionMode.drawing;

  /// Check if a marker is selected
  bool get hasSelection => _selectedMarkers.isNotEmpty;

  /// Check if multiple markers are selected
  bool get hasMultiSelection => _selectedMarkers.length > 1;

  /// Check if can undo
  bool get canUndo => _historyPosition >= 0;

  /// Check if can redo
  bool get canRedo => _historyPosition < _actionHistory.length - 1;

  // Mode management
  void setMode(GDrawingToolsInteractionMode newMode) {
    if (_mode.value != newMode) {
      final oldMode = _mode.value;
      _mode.value = newMode;
      _onModeChanged(oldMode, newMode);
    }
  }

  // Marker management
  void setActiveMarker(GOverlayMarker? marker) {
    _activeMarker.value = marker;
  }

  void setActiveHandle(String? handle) {
    _activeHandle.value = handle;
  }

  // Position management
  void setStartPosition(Offset? position) {
    _startPosition.value = position;
  }

  void setCurrentPosition(Offset? position) {
    _currentPosition.value = position;
  }

  // Selection management
  void selectMarker(GOverlayMarker marker, {bool clearOthers = true}) {
    if (clearOthers || !multiSelectionEnabled) {
      clearSelection();
    }
    
    if (!_selectedMarkers.contains(marker)) {
      _selectedMarkers.add(marker);
      marker.selected = true;
    }
  }

  void deselectMarker(GOverlayMarker marker) {
    if (_selectedMarkers.contains(marker)) {
      _selectedMarkers.remove(marker);
      marker.selected = false;
    }
  }

  void toggleMarkerSelection(GOverlayMarker marker) {
    if (_selectedMarkers.contains(marker)) {
      deselectMarker(marker);
    } else {
      selectMarker(marker, clearOthers: false);
    }
  }

  void clearSelection() {
    for (final marker in _selectedMarkers) {
      marker.selected = false;
    }
    _selectedMarkers.clear();
  }

  // Settings management
  void setSnapEnabled(bool enabled) {
    _snapEnabled.value = enabled;
  }

  void setSnapTolerance(double tolerance) {
    _snapTolerance.value = tolerance;
  }

  void setGridAlignmentEnabled(bool enabled) {
    _gridAlignmentEnabled.value = enabled;
  }

  void setGridSize(double size) {
    _gridSize.value = size;
  }

  void setInteractionSensitivity(double sensitivity) {
    _interactionSensitivity.value = sensitivity;
  }

  void setMultiSelectionEnabled(bool enabled) {
    _multiSelectionEnabled.value = enabled;
    if (!enabled && hasMultiSelection) {
      // Keep only the first selected marker
      final firstSelected = _selectedMarkers.first;
      clearSelection();
      selectMarker(firstSelected);
    }
  }

  // Snapping utilities
  Offset? snapPosition(Offset position, List<Offset> snapTargets) {
    if (!snapEnabled) return position;

    for (final target in snapTargets) {
      final distance = (position - target).distance;
      if (distance <= snapTolerance) {
        return target;
      }
    }

    return gridAlignmentEnabled ? _snapToGrid(position) : position;
  }

  Offset _snapToGrid(Offset position) {
    final gridX = (position.dx / gridSize).round() * gridSize;
    final gridY = (position.dy / gridSize).round() * gridSize;
    return Offset(gridX, gridY);
  }

  List<Offset> generateSnapTargets(List<GOverlayMarker> markers) {
    final snapTargets = <Offset>[];
    
    // Add key points from existing markers
    for (final marker in markers) {
      if (_selectedMarkers.contains(marker)) continue; // Skip selected markers
      
      // Add coordinate positions as snap targets
      // This would need to be implemented with viewport conversion
      // snapTargets.addAll(marker.keyCoordinates.map(...));
    }

    return snapTargets;
  }

  // Action history management
  void recordAction(GDrawingToolsAction action) {
    // Remove any actions after current position (for redo)
    if (_historyPosition < _actionHistory.length - 1) {
      _actionHistory.removeRange(_historyPosition + 1, _actionHistory.length);
    }

    _actionHistory.add(action);
    _historyPosition = _actionHistory.length - 1;

    // Limit history size
    const maxHistorySize = 100;
    if (_actionHistory.length > maxHistorySize) {
      _actionHistory.removeAt(0);
      _historyPosition--;
    }
  }

  bool undo() {
    if (!canUndo) return false;

    final action = _actionHistory[_historyPosition];
    action.undo();
    _historyPosition--;
    return true;
  }

  bool redo() {
    if (!canRedo) return false;

    _historyPosition++;
    final action = _actionHistory[_historyPosition];
    action.redo();
    return true;
  }

  void clearHistory() {
    _actionHistory.clear();
    _historyPosition = -1;
  }

  // State reset
  void reset() {
    setMode(GDrawingToolsInteractionMode.idle);
    setActiveMarker(null);
    setActiveHandle(null);
    setStartPosition(null);
    setCurrentPosition(null);
    clearSelection();
    clearHistory();
  }

  void _onModeChanged(
    GDrawingToolsInteractionMode oldMode,
    GDrawingToolsInteractionMode newMode,
  ) {
    // Handle mode transitions
    switch (newMode) {
      case GDrawingToolsInteractionMode.idle:
        setActiveMarker(null);
        setActiveHandle(null);
        setStartPosition(null);
        setCurrentPosition(null);
        break;
      case GDrawingToolsInteractionMode.drawing:
        clearSelection();
        break;
      case GDrawingToolsInteractionMode.selected:
        // Keep current state
        break;
      case GDrawingToolsInteractionMode.manipulating:
        // Interaction started
        break;
      case GDrawingToolsInteractionMode.contextMenu:
      case GDrawingToolsInteractionMode.properties:
        // UI mode changes
        break;
    }
  }

  // Debugging
  @override
  String toString() {
    return 'GDrawingToolsInteractionState{'
           'mode: $mode, '
           'activeMarker: ${activeMarker?.id}, '
           'activeHandle: $activeHandle, '
           'selectedCount: ${_selectedMarkers.length}, '
           'canUndo: $canUndo, '
           'canRedo: $canRedo'
           '}';
  }
}

/// Base class for actions that can be undone/redone
abstract class GDrawingToolsAction {
  final String description;
  final DateTime timestamp;

  GDrawingToolsAction(this.description) : timestamp = DateTime.now();

  void undo();
  void redo();
}

/// Action for creating a marker
class GCreateMarkerAction extends GDrawingToolsAction {
  final GOverlayMarker marker;
  final Function() onAdd;
  final Function() onRemove;

  GCreateMarkerAction({
    required this.marker,
    required this.onAdd,
    required this.onRemove,
  }) : super('Create ${marker.runtimeType}');

  @override
  void undo() => onRemove();

  @override
  void redo() => onAdd();
}

/// Action for moving a marker
class GMoveMarkerAction extends GDrawingToolsAction {
  final GOverlayMarker marker;
  final List<dynamic> originalCoordinates;
  final List<dynamic> newCoordinates;

  GMoveMarkerAction({
    required this.marker,
    required this.originalCoordinates,
    required this.newCoordinates,
  }) : super('Move ${marker.runtimeType}');

  @override
  void undo() {
    marker.keyCoordinates.clear();
    marker.keyCoordinates.addAll(originalCoordinates.cast());
  }

  @override
  void redo() {
    marker.keyCoordinates.clear();
    marker.keyCoordinates.addAll(newCoordinates.cast());
  }
}

/// Action for deleting a marker
class GDeleteMarkerAction extends GDrawingToolsAction {
  final GOverlayMarker marker;
  final Function() onAdd;
  final Function() onRemove;

  GDeleteMarkerAction({
    required this.marker,
    required this.onAdd,
    required this.onRemove,
  }) : super('Delete ${marker.runtimeType}');

  @override
  void undo() => onAdd();

  @override
  void redo() => onRemove();
}

/// Action for modifying marker properties
class GModifyMarkerAction extends GDrawingToolsAction {
  final GOverlayMarker marker;
  final Map<String, dynamic> originalProperties;
  final Map<String, dynamic> newProperties;

  GModifyMarkerAction({
    required this.marker,
    required this.originalProperties,
    required this.newProperties,
  }) : super('Modify ${marker.runtimeType}');

  @override
  void undo() {
    _applyProperties(originalProperties);
  }

  @override
  void redo() {
    _applyProperties(newProperties);
  }

  void _applyProperties(Map<String, dynamic> properties) {
    // Apply properties to marker
    // This would need specific implementation for each marker type
    for (final entry in properties.entries) {
      // Example: marker.setProperty(entry.key, entry.value);
    }
  }
}