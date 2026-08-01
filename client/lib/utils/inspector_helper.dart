import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Sets up a listener on the [WidgetInspectorService] selection.
/// When in debug mode, it captures the creation location of the selected widget
/// (resolving to the nearest project widget) and copies the path to the clipboard
/// in a Markdown link format.
void setupInspectorListener() {
  if (kDebugMode) {
    // Override debugPrint to filter out the annoying previousSelectionId warning
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.contains('previousSelectionId is deprecated in API')) {
        return; // Suppress it!
      }
      originalDebugPrint(message, wrapWidth: wrapWidth);
    };

    String? lastPrintedLocation;
    WidgetInspectorService.instance.selection.addListener(() async {
      final selectedElement = WidgetInspectorService.instance.selection.currentElement;
      if (selectedElement == null) return;

      try {
        // ignore: invalid_use_of_protected_member
        final jsonStr = WidgetInspectorService.instance.getSelectedSummaryWidget(null, 'selection_group');
        final data = json.decode(jsonStr);
        if (data is Map<String, dynamic> && data.containsKey('creationLocation')) {
          final location = data['creationLocation'] as Map<String, dynamic>;
          final file = location['file'] as String?;
          final line = location['line'] as int?;
          if (file != null && line != null) {
            final locationKey = '$file:$line';
            if (locationKey == lastPrintedLocation) return;
            lastPrintedLocation = locationKey;

            final cleanPath = file.startsWith('file://') ? file.substring(7) : file;
            final filename = cleanPath.split('/').last;
            final clipboardText = '[$filename:$line](<$cleanPath:$line>)';

            await Clipboard.setData(ClipboardData(text: clipboardText));
            print('🎯 Selected Widget: ${selectedElement.widget.runtimeType}');
            print('📍 Location: $cleanPath:$line');
            print('📋 Copied to Clipboard: $clipboardText');
          }
        }
      } catch (_) {
        // Silent catch to prevent console pollution
      }
    });
  }
}
