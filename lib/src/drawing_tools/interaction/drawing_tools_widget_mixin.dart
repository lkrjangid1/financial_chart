import 'package:financial_chart/financial_chart.dart';
import 'package:financial_chart/src/chart_interaction.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../chart.dart';
import '../../chart_widget.dart';
import '../drawing_tools_manager.dart';
import 'drawing_tools_interaction_handler.dart';
import 'drawing_tools_gesture_factory.dart';

/// Mixin that adds drawing tools functionality to chart widgets
mixin GDrawingToolsWidgetMixin<T extends StatefulWidget> on State<T> {
  /// The drawing tools interaction handler
  late final GDrawingToolsInteractionHandler _drawingToolsHandler;
  
  /// The drawing tools manager
  GDrawingToolsManager? _drawingToolsManager;

  /// Whether drawing tools are enabled
  bool get drawingToolsEnabled => _drawingToolsHandler.drawingToolsEnabled;

  /// Get the drawing tools manager
  GDrawingToolsManager? get drawingToolsManager => _drawingToolsManager;

  /// Get the interaction handler
  GDrawingToolsInteractionHandler get drawingToolsHandler => _drawingToolsHandler;

  /// Initialize drawing tools (call this in initState)
  void initializeDrawingTools(GChart chart) {
    _drawingToolsHandler = GDrawingToolsInteractionHandler();
    _drawingToolsHandler.attach(chart);
  }

  /// Set up drawing tools manager for a specific graph
  void setupDrawingToolsManager(GChart chart, GGraph graph) {
    _drawingToolsManager = GDrawingToolsManager(
      chart: chart,
      graph: graph,
    );
    _drawingToolsHandler.setDrawingToolsManager(_drawingToolsManager);
  }

  /// Enable or disable drawing tools
  void setDrawingToolsEnabled(bool enabled) {
    _drawingToolsHandler.setDrawingToolsEnabled(enabled);
    if (mounted) {
      setState(() {});
    }
  }

  /// Select a drawing tool type
  void selectDrawingTool(DrawingToolType? toolType) {
    _drawingToolsManager?.selectTool(toolType);
    if (mounted) {
      setState(() {});
    }
  }

  /// Clear all drawing tools
  void clearAllDrawingTools() {
    _drawingToolsManager?.clearAllTools();
    if (mounted) {
      setState(() {});
    }
  }

  /// Create gesture recognizers that include drawing tools support
  Map<Type, GestureRecognizerFactory> createDrawingToolsGestures(
    BuildContext context, {
    Set<PointerDeviceKind>? supportedDevices,
  }) {
    return _drawingToolsHandler.createCompleteGestureRecognizers(
      context,
      supportedDevices: supportedDevices,
    );
  }

  /// Build a chart widget with drawing tools support
  Widget buildChartWithDrawingTools({
    required GChart chart,
    TickerProvider? tickerProvider,
    Set<PointerDeviceKind>? supportedDevices,
    Widget? child,
  }) {
    return RawGestureDetector(
      // Use enhanced gesture recognizers
      gestures: createDrawingToolsGestures(
        context,
        supportedDevices: supportedDevices,
      ),
      child: MouseRegion(
        onEnter: (event) => _drawingToolsHandler.mouseEnter(
          position: event.localPosition,
        ),
        onExit: (event) => _drawingToolsHandler.mouseExit(),
        onHover: (event) => _drawingToolsHandler.mouseHover(
          position: event.localPosition,
        ),
        child: child ?? GChartWidget(
          chart: chart,
          tickerProvider: tickerProvider ?? this as TickerProvider,
          supportedDevices: supportedDevices,
        ),
      ),
    );
  }

  /// Dispose drawing tools resources
  void disposeDrawingTools() {
    _drawingToolsManager = null;
    // Handler doesn't need explicit disposal as it extends the main handler
  }
}

/// Enhanced chart widget that includes drawing tools functionality
class GDrawingToolsChartWidget extends StatefulWidget {
  final GChart chart;
  final GChartInteractionHandler? controller;
  final Set<PointerDeviceKind>? supportedDevices;
  final bool drawingToolsEnabled;
  final DrawingToolType? selectedTool;
  final void Function(DrawingToolType? toolType)? onToolSelected;
  final void Function(GOverlayMarker marker)? onMarkerSelected;
  final void Function(GOverlayMarker marker)? onMarkerCreated;
  final void Function(GOverlayMarker marker)? onMarkerDeleted;
  final Widget? child;

  const GDrawingToolsChartWidget({
    Key? key,
    required this.chart,
    this.controller,
    this.supportedDevices,
    this.drawingToolsEnabled = false,
    this.selectedTool,
    this.onToolSelected,
    this.onMarkerSelected,
    this.onMarkerCreated,
    this.onMarkerDeleted,
    this.child,
  }) : super(key: key);

  @override
  State<GDrawingToolsChartWidget> createState() => _GDrawingToolsChartWidgetState();
}

class _GDrawingToolsChartWidgetState extends State<GDrawingToolsChartWidget> 
    with GDrawingToolsWidgetMixin {
  
  @override
  void initState() {
    super.initState();
    initializeDrawingTools(widget.chart);
    
    // Set up drawing tools manager for the first graph
    if (widget.chart.panels.isNotEmpty && 
        widget.chart.panels.first.graphs.isNotEmpty) {
      setupDrawingToolsManager(
        widget.chart,
        widget.chart.panels.first.graphs.first,
      );
    }
    
    setDrawingToolsEnabled(widget.drawingToolsEnabled);
    
    if (widget.selectedTool != null) {
      selectDrawingTool(widget.selectedTool);
    }
  }

  @override
  void didUpdateWidget(GDrawingToolsChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.drawingToolsEnabled != oldWidget.drawingToolsEnabled) {
      setDrawingToolsEnabled(widget.drawingToolsEnabled);
    }
    
    if (widget.selectedTool != oldWidget.selectedTool) {
      selectDrawingTool(widget.selectedTool);
    }
  }

  @override
  void dispose() {
    disposeDrawingTools();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildChartWithDrawingTools(
      chart: widget.chart,
      supportedDevices: widget.supportedDevices,
      child: widget.child,
    );
  }
}

/// Toolbar widget for drawing tools
class GDrawingToolsToolbar extends StatelessWidget {
  final DrawingToolType? selectedTool;
  final void Function(DrawingToolType? toolType) onToolSelected;
  final VoidCallback? onClearAll;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  const GDrawingToolsToolbar({
    Key? key,
    this.selectedTool,
    required this.onToolSelected,
    this.onClearAll,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolButton(
          context,
          'H-Line',
          Icons.horizontal_rule,
          DrawingToolType.horizontalLine,
        ),
        _buildToolButton(
          context,
          'Trend',
          Icons.trending_up,
          DrawingToolType.trendLine,
        ),
        _buildToolButton(
          context,
          'Measure',
          Icons.straighten,
          DrawingToolType.measure,
        ),
        _buildToolButton(
          context,
          'Rectangle',
          Icons.crop_square,
          DrawingToolType.rectangle,
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo),
          tooltip: 'Undo',
        ),
        IconButton(
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo),
          tooltip: 'Redo',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onClearAll,
          icon: const Icon(Icons.clear_all),
          tooltip: 'Clear All',
        ),
      ],
    );
  }

  Widget _buildToolButton(
    BuildContext context,
    String label,
    IconData icon,
    DrawingToolType toolType,
  ) {
    final isSelected = selectedTool == toolType;
    
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onToolSelected(isSelected ? null : toolType),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : null,
            size: 20,
          ),
        ),
      ),
    );
  }
}