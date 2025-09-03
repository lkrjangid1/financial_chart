import 'dart:ui';

import '../chart.dart';
import '../components/components.dart';
import '../values/coord.dart';
import 'drawing_tools.dart';
import 'drawing_tools_handler.dart';

/// Available drawing tool types
enum DrawingToolType {
  horizontalLine,
  trendLine,
  measure,
  rectangle,
}

/// Manager class for handling drawing tools creation and interaction
class GDrawingToolsManager {
  final GChart chart;
  final GGraph graph;
  
  /// Currently selected drawing tool type
  DrawingToolType? _selectedTool;
  
  /// Tool being actively created
  GOverlayMarker? _activeTool;
  
  /// Temporary coordinates during tool creation
  final List<GCoordinate> _tempCoordinates = [];
  
  /// Whether the manager is in drawing mode
  bool _isDrawingMode = false;

  GDrawingToolsManager({
    required this.chart,
    required this.graph,
  });

  /// Get the currently selected drawing tool
  DrawingToolType? get selectedTool => _selectedTool;
  
  /// Check if in drawing mode
  bool get isDrawingMode => _isDrawingMode;
  
  /// Get the active tool being created
  GOverlayMarker? get activeTool => _activeTool;

  /// Set the selected drawing tool type
  void selectTool(DrawingToolType? toolType) {
    _selectedTool = toolType;
    _isDrawingMode = toolType != null;

    if (!_isDrawingMode) {
      _cancelActiveTool();
    }
  }

  /// Handle mouse/touch down event for drawing tools
  bool handlePointerDown(Offset position) {
    if (!_isDrawingMode || _selectedTool == null) return false;
    
    final panel = chart.panels.first; // Assuming single panel for now
    final pointViewPort = chart.pointViewPort;
    final valueViewPort = panel.findValueViewPortById(graph.valueViewPortId);
    final area = panel.graphArea();
    
    if (!area.contains(position)) return false;
    
    // Convert position to chart coordinates
    final coord = GViewPortCoord.fromPosition(
      area: area,
      position: position,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );
    
    _tempCoordinates.add(coord);
    
    // Handle different tool creation flows
    switch (_selectedTool!) {
      case DrawingToolType.horizontalLine:
        _createHorizontalLine(coord);
        break;
        
      case DrawingToolType.trendLine:
        _handleTrendLineCreation(coord);
        break;
        
      case DrawingToolType.measure:
        _handleMeasureCreation(coord);
        break;
        
      case DrawingToolType.rectangle:
        _handleRectangleCreation(coord);
        break;
    }
    
    return true;
  }

  /// Handle mouse/touch move event during tool creation
  bool handlePointerMove(Offset position) {
    if (!_isDrawingMode || _activeTool == null) return false;
    
    final panel = chart.panels.first;
    final pointViewPort = chart.pointViewPort;
    final valueViewPort = panel.findValueViewPortById(graph.valueViewPortId);
    final area = panel.graphArea();
    
    if (!area.contains(position)) return false;
    
    // Convert position to chart coordinates
    final coord = GViewPortCoord.fromPosition(
      area: area,
      position: position,
      valueViewPort: valueViewPort,
      pointViewPort: pointViewPort,
    );
    
    // Update the active tool's coordinates
    _updateActiveToolCoordinates(coord);
    
    return true;
  }

  /// Handle mouse/touch up event to finalize tool creation
  bool handlePointerUp(Offset position) {
    if (!_isDrawingMode) return false;
    
    // Finalize the active tool if it exists
    if (_activeTool != null) {
      _finalizeActiveTool();
      return true;
    }
    
    return false;
  }

  void _createHorizontalLine(GCoordinate coord) {
    if (_tempCoordinates.length == 1) {
      // Start creating trend line
      _activeTool = GHorizontalLineMarker(
        id: 'h_line_${DateTime.now().millisecondsSinceEpoch}',
        value: coord.y,
        thickness: 10,
        // scaleHandler: GDrawingToolsScaleHandler(_activeTool as GHorizontalLineMarker),
      );

      graph.addMarker(_activeTool!);
    }



    // final horizontalLine = GHorizontalLineMarker(
    //   id: 'h_line_${DateTime.now().millisecondsSinceEpoch}',
    //   value: coord.y,
    //   thickness: 5,
    //   // scaleHandler: GDrawingToolsScaleHandler(_activeTool as GHorizontalLineMarker),
    // );

    // graph.addMarker(horizontalLine);
    _finishToolCreation();
  }

  void _handleTrendLineCreation(GCoordinate coord) {
    if (_tempCoordinates.length == 1) {
      // Start creating trend line
      _activeTool = GTrendLineMarker(
        id: 'trend_line_${DateTime.now().millisecondsSinceEpoch}',
        startPoint: coord as GViewPortCoord,
        endPoint: coord, // Will be updated on move
      );
      
      graph.addMarker(_activeTool!);
    }
    _finishToolCreation();
  }

  void _handleMeasureCreation(GCoordinate coord) {
    if (_tempCoordinates.length == 1) {
      // Start creating measure tool
      _activeTool = GMeasureMarker(
        id: 'measure_${DateTime.now().millisecondsSinceEpoch}',
        startPoint: coord as GViewPortCoord,
        endPoint: coord, // Will be updated on move
      );
      
      graph.addMarker(_activeTool!);
    }
  }

  void _handleRectangleCreation(GCoordinate coord) {
    if (_tempCoordinates.length == 1) {
      // Start creating rectangle
      _activeTool = GRectangleMarker(
        id: 'rectangle_${DateTime.now().millisecondsSinceEpoch}',
        topLeft: coord as GViewPortCoord,
        bottomRight: coord, // Will be updated on move
      );
      
      graph.addMarker(_activeTool!);
    }
  }

  void _updateActiveToolCoordinates(GCoordinate coord) {
    if (_activeTool == null) return;
    
    switch (_activeTool.runtimeType) {
      case GTrendLineMarker:
        final trendLine = _activeTool as GTrendLineMarker;
        trendLine.updateEndPoint(coord as GViewPortCoord);
        break;
        
      case GMeasureMarker:
        final measure = _activeTool as GMeasureMarker;
        measure.updateEndPoint(coord as GViewPortCoord);
        break;
        
      case GRectangleMarker:
        final rectangle = _activeTool as GRectangleMarker;
        rectangle.updateBottomRight(coord as GViewPortCoord);
        break;
    }
  }

  void _finalizeActiveTool() {
    if (_activeTool == null) return;
    
    // Add scale handler for interactive manipulation
    switch (_activeTool.runtimeType) {
      case GTrendLineMarker:
        final trendLine = _activeTool as GTrendLineMarker;
        trendLine.scaleHandler = GDrawingToolsScaleHandler(trendLine);
        break;
        
      case GMeasureMarker:
        final measure = _activeTool as GMeasureMarker;
        measure.scaleHandler = GDrawingToolsScaleHandler(measure);
        break;
        
      case GRectangleMarker:
        final rectangle = _activeTool as GRectangleMarker;
        rectangle.scaleHandler = GDrawingToolsScaleHandler(rectangle);
        break;
    }
    
    _finishToolCreation();
  }

  void _finishToolCreation() {
    _activeTool = null;
    _tempCoordinates.clear();
    
    // Optionally exit drawing mode after creating one tool
    // _isDrawingMode = false;
    // _selectedTool = null;
  }

  void _cancelActiveTool() {
    if (_activeTool != null) {
      graph.removeMarker(_activeTool!);
      _activeTool = null;
    }
    _tempCoordinates.clear();
  }

  /// Remove a specific drawing tool
  bool removeTool(String toolId) {
    final marker = graph.findMarker(toolId);
    if (marker != null) {
      return graph.removeMarker(marker);
    }
    return false;
  }

  /// Clear all drawing tools
  void clearAllTools() {
    // Get all drawing tools (filter by type)
    final drawingTools = graph.overlayMarkers.where((marker) {
      return marker is GHorizontalLineMarker ||
             marker is GTrendLineMarker ||
             marker is GMeasureMarker ||
             marker is GRectangleMarker;
    }).toList();
    
    for (final tool in drawingTools) {
      graph.removeMarker(tool);
    }
  }

  /// Get all drawing tools of a specific type
  List<T> getToolsByType<T extends GOverlayMarker>() {
    return graph.overlayMarkers
        .whereType<T>()
        .toList();
  }

  /// Export drawing tools configuration (for persistence)
  Map<String, dynamic> exportTools() {
    final tools = <Map<String, dynamic>>[];
    
    for (final marker in graph.overlayMarkers) {
      if (marker is GHorizontalLineMarker ||
          marker is GTrendLineMarker ||
          marker is GMeasureMarker ||
          marker is GRectangleMarker) {
        
        final toolData = <String, dynamic>{
          'id': marker.id,
          'type': marker.runtimeType.toString(),
          'visible': marker.visible,
          'coordinates': marker.keyCoordinates.map((coord) {
            if (coord is GViewPortCoord) {
              return {
                'point': coord.point,
                'value': coord.value,
              };
            }
            return null;
          }).where((c) => c != null).toList(),
        };
        
        // Add tool-specific properties
        if (marker is GHorizontalLineMarker) {
          toolData.addAll({
            'color': marker.color.value,
            'thickness': marker.thickness,
            'extendAcrossChart': marker.extendAcrossChart,
          });
        } else if (marker is GTrendLineMarker) {
          toolData.addAll({
            'color': marker.color.value,
            'thickness': marker.thickness,
            'extendLine': marker.extendLine,
            'showInfo': marker.showInfo,
          });
        } else if (marker is GMeasureMarker) {
          toolData.addAll({
            'color': marker.color.value,
            'thickness': marker.thickness,
            'showInfo': marker.showInfo,
            'showGrid': marker.showGrid,
          });
        } else if (marker is GRectangleMarker) {
          toolData.addAll({
            'fillColor': marker.fillColor?.value,
            'borderColor': marker.borderColor.value,
            'borderThickness': marker.borderThickness,
            'fillOpacity': marker.fillOpacity,
            'showDimensions': marker.showDimensions,
            'cornerRadius': marker.cornerRadius,
          });
        }
        
        tools.add(toolData);
      }
    }
    
    return {
      'version': '1.0',
      'tools': tools,
    };
  }

  /// Import drawing tools from configuration (for persistence)
  void importTools(Map<String, dynamic> config) {
    clearAllTools();
    
    final tools = config['tools'] as List<dynamic>? ?? [];
    
    for (final toolData in tools) {
      final data = toolData as Map<String, dynamic>;
      final type = data['type'] as String;
      final coordinates = (data['coordinates'] as List<dynamic>)
          .map((c) => GViewPortCoord(
                point: c['point'] as double,
                value: c['value'] as double,
              ))
          .toList();
      
      GOverlayMarker? marker;
      
      switch (type) {
        case 'GHorizontalLineMarker':
          if (coordinates.isNotEmpty) {
            marker = GHorizontalLineMarker(
              id: data['id'],
              value: coordinates.first.value,
              color: Color(data['color'] as int),
              thickness: data['thickness'] as double,
              extendAcrossChart: data['extendAcrossChart'] as bool,
              visible: data['visible'] as bool,
            );
          }
          break;
          
        case 'GTrendLineMarker':
          if (coordinates.length >= 2) {
            marker = GTrendLineMarker(
              id: data['id'],
              startPoint: coordinates[0],
              endPoint: coordinates[1],
              color: Color(data['color'] as int),
              thickness: data['thickness'] as double,
              extendLine: data['extendLine'] as bool,
              showInfo: data['showInfo'] as bool,
              visible: data['visible'] as bool,
            );
          }
          break;
          
        case 'GMeasureMarker':
          if (coordinates.length >= 2) {
            marker = GMeasureMarker(
              id: data['id'],
              startPoint: coordinates[0],
              endPoint: coordinates[1],
              color: Color(data['color'] as int),
              thickness: data['thickness'] as double,
              showInfo: data['showInfo'] as bool,
              showGrid: data['showGrid'] as bool,
              visible: data['visible'] as bool,
            );
          }
          break;
          
        case 'GRectangleMarker':
          if (coordinates.length >= 2) {
            marker = GRectangleMarker(
              id: data['id'],
              topLeft: coordinates[0],
              bottomRight: coordinates[1],
              fillColor: data['fillColor'] != null 
                  ? Color(data['fillColor'] as int) 
                  : null,
              borderColor: Color(data['borderColor'] as int),
              borderThickness: data['borderThickness'] as double,
              fillOpacity: data['fillOpacity'] as double,
              showDimensions: data['showDimensions'] as bool,
              cornerRadius: data['cornerRadius'] as double,
              visible: data['visible'] as bool,
            );
          }
          break;
      }
      if (marker != null) {
        marker.scaleHandler = GDrawingToolsScaleHandler(marker);
        graph.addMarker(marker);
      }
    }
  }
}