import 'package:flutter/material.dart';
import 'package:financial_chart/financial_chart.dart';

import '../data/sample_data_loader.dart';

class DrawingToolsDemoPage extends StatefulWidget {
  const DrawingToolsDemoPage({super.key});

  @override
  DrawingToolsDemoPageState createState() => DrawingToolsDemoPageState();
}

class DrawingToolsDemoPageState extends State<DrawingToolsDemoPage>
    with TickerProviderStateMixin, GDrawingToolsWidgetMixin {
  GChart? chart;
  // GDrawingToolsKeyboardHandler? keyboardHandler;
  DrawingToolType? selectedTool;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeChart();
  }

  @override
  void dispose() {
    chart?.dispose();
    disposeDrawingTools();
    super.dispose();
  }

  Future<void> initializeChart() async {
    try {
      // Load data
      final response = await loadYahooFinanceData('AAPL');

      // Build data source
      final dataSource = GDataSource<int, GData<int>>(
        dataList: response.candlesData.map((candle) {
          return GData<int>(
            pointValue: candle.date.millisecondsSinceEpoch,
            seriesValues: [
              candle.open,
              candle.high,
              candle.low,
              candle.close,
              candle.volume.toDouble(),
            ],
          );
        }).toList(),
        seriesProperties: const [
          GDataSeriesProperty(key: 'open', label: 'Open', precision: 2),
          GDataSeriesProperty(key: 'high', label: 'High', precision: 2),
          GDataSeriesProperty(key: 'low', label: 'Low', precision: 2),
          GDataSeriesProperty(key: 'close', label: 'Close', precision: 2),
          GDataSeriesProperty(key: 'volume', label: 'Volume', precision: 0),
        ],
      );

      final builtChart = buildChart(dataSource);

      // Initialize drawing tools
      initializeDrawingTools(builtChart);

      // Setup drawing tools manager for the OHLC graph
      final mainPanel = builtChart.panels.first;
      final ohlcGraph = mainPanel.graphs
          .firstWhere((graph) => graph is GGraphOhlc, orElse: () => mainPanel.graphs.first);

      setupDrawingToolsManager(builtChart, ohlcGraph);

      // Setup keyboard handler
      // keyboardHandler = GDrawingToolsKeyboardHandler(
      //   interactionHandler: drawingToolsHandler,
      //   drawingToolsManager: drawingToolsManager,
      // );

      // Enable drawing tools
      setDrawingToolsEnabled(true);

      setState(() {
        chart = builtChart;
        isLoading = false;
      });

      // Add some sample drawing tools after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _addSampleDrawingToolsAsync();
      });

    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  GChart buildChart(GDataSource dataSource) {
    return GChart(
      dataSource: dataSource,
      theme: GThemeDark(),
      panels: [
        GPanel(
          valueViewPorts: [
            GValueViewPort(
              valuePrecision: 2,
              autoScaleStrategy: GValueViewPortAutoScaleStrategyMinMax(
                dataKeys: ["high", "low"],
                marginStart: GSize.viewHeightRatio(0.3),
              ),
            ),
            GValueViewPort(
              id: "volume",
              valuePrecision: 0,
              autoScaleStrategy: GValueViewPortAutoScaleStrategyMinMax(
                dataKeys: ["volume"],
                marginStart: GSize.viewSize(0),
                marginEnd: GSize.viewHeightRatio(0.7),
              ),
            ),
          ],
          valueAxes: [
            GValueAxis(),
            GValueAxis(viewPortId: "volume", position: GAxisPosition.start),
          ],
          pointAxes: [GPointAxis()],
          graphs: [
            GGraphGrids(),
            GGraphOhlc(ohlcValueKeys: const ["open", "high", "low", "close"]),
            GGraphBar(valueKey: "volume", valueViewPortId: "volume"),
          ],
        ),
      ],
    );
  }

  void _onToolSelected(DrawingToolType? toolType) {
    setState(() {
      selectedTool = toolType;
    });
    selectDrawingTool(toolType);
  }

  Future<void> _addSampleDrawingToolsAsync() async {
    if (chart == null || chart!.dataSource.isEmpty) return;

    final mainPanel = chart!.panels.first;
    final ohlcGraph = mainPanel.graphs
        .firstWhere((graph) => graph is GGraphOhlc, orElse: () => mainPanel.graphs.first);

    // Get some sample price data for realistic tool placement
    final dataList = chart!.dataSource.dataList as List<GData<int>>;
    if (dataList.length < 20) return;

    // Add tools one by one with delays to avoid blocking UI
    await _addHorizontalLineSample(ohlcGraph, dataList);
    // await Future.delayed(const Duration(milliseconds: 100));
    //
    // if (!mounted) return;
    // await _addTrendLineSample(ohlcGraph, dataList);
    // await Future.delayed(const Duration(milliseconds: 100));
    //
    // if (!mounted) return;
    // await _addRectangleSample(ohlcGraph, dataList);
    // await Future.delayed(const Duration(milliseconds: 100));
    //
    // if (!mounted) return;
    // await _addMeasureSample(ohlcGraph, dataList);

    if (mounted) {
      setState(() {}); // Single setState at the end
    }
  }

  Future<void> _addHorizontalLineSample(GGraph ohlcGraph, List<GData<int>> dataList) async {
    final currentHigh = dataList.last.seriesValues[1];
    final hLine = GHorizontalLineMarker(
      id: 'support_line',
      value: currentHigh * 0.95,
      color: Colors.red,
      thickness: 2.0,
      extendAcrossChart: true,
    );
    hLine.scaleHandler = GDrawingToolsScaleHandler(hLine);
    ohlcGraph.addMarker(hLine);
  }

  Future<void> _addTrendLineSample(GGraph ohlcGraph, List<GData<int>> dataList) async {
    final startIndex = dataList.length ~/ 4;
    final endIndex = dataList.length * 3 ~/ 4;
    final startData = dataList[startIndex];
    final endData = dataList[endIndex];

    final trendLine = GTrendLineMarker(
      id: 'uptrend_line',
      startPoint: GViewPortCoord(
        point: startData.pointValue.toDouble(),
        value: startData.seriesValues[2],
      ),
      endPoint: GViewPortCoord(
        point: endData.pointValue.toDouble(),
        value: endData.seriesValues[1],
      ),
      color: Colors.orange,
      thickness: 1.5,
      extendLine: false, // Disable extension to reduce complexity
      showInfo: false, // Disable info to reduce rendering
    );
    trendLine.scaleHandler = GDrawingToolsScaleHandler(trendLine);
    ohlcGraph.addMarker(trendLine);
  }

  Future<void> _addRectangleSample(GGraph ohlcGraph, List<GData<int>> dataList) async {
    final currentHigh = dataList.last.seriesValues[1];
    final midIndex = dataList.length ~/ 2;
    final midData = dataList[midIndex];

    final rectangle = GRectangleMarker(
      id: 'resistance_zone',
      topLeft: GViewPortCoord(
        point: midData.pointValue.toDouble(),
        value: currentHigh * 1.02,
      ),
      bottomRight: GViewPortCoord(
        point: dataList.last.pointValue.toDouble(),
        value: currentHigh * 0.98,
      ),
      fillColor: Colors.blue.withOpacity(0.1),
      borderColor: Colors.blue,
      borderThickness: 1.0,
      fillOpacity: 0.1, // Reduce opacity to improve performance
      showDimensions: false, // Disable to reduce rendering complexity
    );
    rectangle.scaleHandler = GDrawingToolsScaleHandler(rectangle);
    ohlcGraph.addMarker(rectangle);
  }

  Future<void> _addMeasureSample(GGraph ohlcGraph, List<GData<int>> dataList) async {
    final measureStartIndex = dataList.length ~/ 3;
    final measureEndIndex = dataList.length * 2 ~/ 3;
    final measureStart = dataList[measureStartIndex];
    final measureEnd = dataList[measureEndIndex];

    final measure = GMeasureMarker(
      id: 'price_move_measure',
      startPoint: GViewPortCoord(
        point: measureStart.pointValue.toDouble(),
        value: measureStart.seriesValues[3],
      ),
      endPoint: GViewPortCoord(
        point: measureEnd.pointValue.toDouble(),
        value: measureEnd.seriesValues[3],
      ),
      color: Colors.purple,
      thickness: 1.0,
      showInfo: false, // Disable to reduce rendering load
      showGrid: false, // Disable to reduce rendering load
      pointFormatter: (point) {
        final date = DateTime.fromMillisecondsSinceEpoch(point.toInt());
        return '${date.month}/${date.day}';
      },
      valueFormatter: (value) => '\${value.toStringAsFixed(2)}',
    );
    measure.scaleHandler = GDrawingToolsScaleHandler(measure);
    ohlcGraph.addMarker(measure);
  }

  void _exportTools() {
    if (drawingToolsManager == null) return;

    final config = drawingToolsManager!.exportTools();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${config['tools'].length} drawing tools'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exported Tools Configuration'),
                content: SingleChildScrollView(
                  child: Text(
                    config.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Drawing Tools Demo"),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading AAPL chart data...'),
              SizedBox(height: 8),
              Text(
                'Initializing drawing tools interface',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (chart == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Drawing Tools Demo"),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load chart data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: initializeChart,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Drawing Tools Demo - AAPL"),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: /*GDrawingToolsKeyboardListener(
        keyboardHandler: keyboardHandler!,
        child:*/ Column(
          children: [
            // Simplified toolbar to reduce initial complexity
            _buildSimplifiedToolbar(),

            // Status bar
            _buildStatusBar(),

            // Chart area with drawing tools
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: buildChartWithDrawingTools(
                  chart: chart!,
                  tickerProvider: this,
                  child: GChartWidget(
                    chart: chart!,
                    tickerProvider: this,
                  ),
                ),
              ),
            ),

            // Simplified info panel
            _buildSimplifiedInfoPanel(),
          ],
        ),
      // ),
    );
  }

  Widget _buildSimplifiedToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Main drawing tools
          GDrawingToolsToolbar(
            selectedTool: selectedTool,
            onToolSelected: _onToolSelected,
            onClearAll: clearAllDrawingTools,
            onUndo: () {
              if (drawingToolsHandler.interactionState.undo()) {
                setState(() {});
              }
            },
            onRedo: () {
              if (drawingToolsHandler.interactionState.redo()) {
                setState(() {});
              }
            },
            canUndo: drawingToolsHandler.interactionState.canUndo,
            canRedo: drawingToolsHandler.interactionState.canRedo,
          ),

          const Spacer(),

          // Export button
          IconButton(
            onPressed: _exportTools,
            icon: const Icon(Icons.download),
            tooltip: 'Export Tools Configuration',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: selectedTool != null ? Colors.orange[50] : Colors.blue[50],
      child: Text(
        _getStatusText(),
        style: TextStyle(
          color: selectedTool != null ? Colors.orange[800] : Colors.blue[800],
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSimplifiedInfoPanel() {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _getDrawingToolsInfo(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Keys: 1-4 (tools) • Esc • Del • Ctrl+Z/Y',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (selectedTool != null) {
      final toolName = selectedTool.toString().split('.').last;
      return 'Drawing Mode: $toolName - Click and drag on the chart to create the tool';
    } else if (drawingToolsHandler.interactionState.hasSelection) {
      final count = drawingToolsHandler.interactionState.selectedMarkers.length;
      return '$count tool${count > 1 ? 's' : ''} selected - Drag to move, use control handles to resize';
    } else {
      return 'Select a drawing tool from the toolbar above, or click on existing tools to select and modify them';
    }
  }

  String _getDrawingToolsInfo() {
    if (chart == null) return 'No chart loaded';

    final mainPanel = chart!.panels.first;
    final ohlcGraph = mainPanel.graphs
        .firstWhere((graph) => graph is GGraphOhlc, orElse: () => mainPanel.graphs.first);

    final drawingTools = ohlcGraph.overlayMarkers.where((marker) =>
    marker is GHorizontalLineMarker ||
        marker is GTrendLineMarker ||
        marker is GMeasureMarker ||
        marker is GRectangleMarker).toList();

    if (drawingTools.isEmpty) {
      return 'No drawing tools added yet.\nUse the toolbar above to select and draw tools.';
    }

    final info = StringBuffer('${drawingTools.length} tools:\n');
    for (final tool in drawingTools) {
      final prefix = tool.selected ? '→ ' : '  ';
      final highlight = tool.highlighted ? ' (hover)' : '';

      if (tool is GHorizontalLineMarker) {
        info.writeln('${prefix}H-Line: \$${tool.value.toStringAsFixed(2)}$highlight');
      } else if (tool is GTrendLineMarker) {
        info.writeln('${prefix}Trend: ${tool.percentageChange.toStringAsFixed(1)}% change$highlight');
      } else if (tool is GMeasureMarker) {
        info.writeln('${prefix}Measure: ${tool.percentageChange.toStringAsFixed(1)}% move$highlight');
      } else if (tool is GRectangleMarker) {
        info.writeln('${prefix}Rectangle: ${tool.area.toStringAsFixed(0)} area$highlight');
      }
    }

    return info.toString();
  }

  String _getInteractionStateInfo() {
    final state = drawingToolsHandler.interactionState;
    final mode = state.mode.toString().split('.').last;

    return 'Mode: $mode\n'
        'Selected: ${state.selectedMarkers.length} tools\n'
        'Snap: ${state.snapEnabled ? 'Enabled' : 'Disabled'}\n'
        'Grid: ${state.gridAlignmentEnabled ? 'Enabled' : 'Disabled'}\n'
        'History: ${state.canUndo ? 'Can Undo' : 'No Undo'}\n'
        'Multi-select: ${state.multiSelectionEnabled ? 'On' : 'Off'}';
  }
}