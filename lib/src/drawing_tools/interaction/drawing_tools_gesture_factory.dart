import 'package:financial_chart/src/chart_interaction.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../chart.dart';
import 'drawing_tools_interaction_handler.dart';
import 'drawing_tools_gesture_recognizers.dart';

/// Extension for creating drawing tools gesture recognizers
extension GDrawingToolsGestures on GDrawingToolsInteractionHandler {
  /// Create gesture recognizers that integrate drawing tools with chart interactions
  Map<Type, GestureRecognizerFactory> createDrawingToolsGestureRecognizers(
    BuildContext context, {
    Set<PointerDeviceKind>? supportedDevices,
  }) {
    final handler = this;
    final team = GestureArenaTeam();
    final gestureSettings = MediaQuery.maybeOf(context)?.gestureSettings;

    return {
      // Enhanced scale gesture recognizer
      GDrawingToolsScaleGestureRecognizer: 
          GestureRecognizerFactoryWithHandlers<GDrawingToolsScaleGestureRecognizer>(
        () => GDrawingToolsScaleGestureRecognizer(
          supportedDevices: supportedDevices,
          chart: chart,
          isDrawingToolsEnabled: () => drawingToolsEnabled,
        )
          ..team = team
          ..gestureSettings = gestureSettings,
        (GDrawingToolsScaleGestureRecognizer instance) {
          team.captain = instance;
          instance.onStart = (details) {
            handler.scaleStart(
              start: details.localFocalPoint,
              pointerCount: details.pointerCount,
            );
          };
          instance.onUpdate = (details) {
            handler.scaleUpdate(
              position: details.localFocalPoint,
              scale: details.scale,
              verticalScale: details.verticalScale,
            );
          };
          instance.onEnd = (details) {
            handler.scaleEnd(
              details.pointerCount,
              details.scaleVelocity,
              details.velocity,
            );
          };
        },
      ),

      // Enhanced tap gesture recognizer for drawing tools
      GDrawingToolsTapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<GDrawingToolsTapGestureRecognizer>(
        () => GDrawingToolsTapGestureRecognizer(
          supportedDevices: supportedDevices,
          chart: chart,
          isDrawingToolsEnabled: () => drawingToolsEnabled,
        )
          ..team = team
          ..gestureSettings = gestureSettings,
        (GDrawingToolsTapGestureRecognizer instance) {
          instance.onTapDown = (details) {
            handler.tapDown(
              position: details.localPosition,
              isTouch: details.kind == PointerDeviceKind.touch,
            );
          };
          instance.onTapUp = (details) {
            handler.tapUp();
          };
        },
      ),

      // Long press for context menus
      GDrawingToolsLongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<GDrawingToolsLongPressGestureRecognizer>(
        () => GDrawingToolsLongPressGestureRecognizer(
          supportedDevices: supportedDevices,
          chart: chart,
          isDrawingToolsEnabled: () => drawingToolsEnabled,
        )
          ..team = team
          ..gestureSettings = gestureSettings,
        (GDrawingToolsLongPressGestureRecognizer instance) {
          instance.onLongPressStart = (details) {
            handler.longPressStart(position: details.localPosition);
          };
          instance.onLongPressMoveUpdate = (details) {
            handler.longPressMove(position: details.localPosition);
          };
          instance.onLongPressEnd = (details) {
            handler.longPressEnd(position: details.localPosition);
          };
        },
      ),

      // Pan gesture for drawing mode
      GDrawingToolsPanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<GDrawingToolsPanGestureRecognizer>(
        () => GDrawingToolsPanGestureRecognizer(
          supportedDevices: supportedDevices,
          chart: chart,
          isDrawingMode: () => drawingToolsManager?.isDrawingMode ?? false,
        )
          ..team = team
          ..gestureSettings = gestureSettings,
        (GDrawingToolsPanGestureRecognizer instance) {
          instance.onStart = (details) {
            if (drawingToolsEnabled && drawingToolsManager?.isDrawingMode == true) {
              drawingToolsManager?.handlePointerDown(details.localPosition);
            }
          };
          instance.onUpdate = (details) {
            if (drawingToolsEnabled && drawingToolsManager?.isDrawingMode == true) {
              drawingToolsManager?.handlePointerMove(details.localPosition);
            }
          };
          instance.onEnd = (details) {
            if (drawingToolsEnabled && drawingToolsManager?.isDrawingMode == true) {
              drawingToolsManager?.handlePointerUp(details.localPosition);
            }
          };
        },
      ),

      // Double tap for properties dialog
      // DoubleTapGestureRecognizer:
      //     GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
      //   () => DoubleTapGestureRecognizer(
      //     supportedDevices: supportedDevices,
      //   )
      //     ..team = team
      //     ..gestureSettings = gestureSettings,
      //   (DoubleTapGestureRecognizer instance) {
      //     instance.onDoubleTap = () {
      //       // Get the last tap position and handle double tap
      //       // This would need to be coordinated with tap handling
      //     };
      //     instance.onDoubleTapDown = (details) {
      //       handler.doubleTap(position: details.localPosition);
      //     };
      //   },
      // ),
    };
  }

  /// Create complete gesture recognizers including both chart and drawing tools
  Map<Type, GestureRecognizerFactory> createCompleteGestureRecognizers(
    BuildContext context, {
    Set<PointerDeviceKind>? supportedDevices,
  }) {
    // Start with drawing tools recognizers
    final recognizers = createDrawingToolsGestureRecognizers(
      context,
      supportedDevices: supportedDevices,
    );

    // Add any missing standard chart recognizers
    final standardRecognizers = createGestureRecognizers(
      context,
      supportedDevices: supportedDevices,
    );

    // Merge, preferring drawing tools recognizers
    for (final entry in standardRecognizers.entries) {
      if (!recognizers.containsKey(entry.key)) {
        recognizers[entry.key] = entry.value;
      }
    }

    return recognizers;
  }
}