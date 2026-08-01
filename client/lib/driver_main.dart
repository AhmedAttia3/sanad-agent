// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';
import 'package:sanad_client/main.dart' as app;
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter/material.dart';

void main() {
  // Enable integration testing with the Flutter Driver extension.
  enableFlutterDriverExtension();

  // Register our custom interactive UI inspection extension
  developer.registerExtension('ext.sanad_client.inspect_ui', (method, parameters) async {
    final widgets = <Map<String, dynamic>>[];

    void walk(Element element) {
      final widget = element.widget;
      final key = widget.key;
      String? keyString;
      if (key != null) {
        if (key is ValueKey) {
          keyString = key.value.toString();
        } else {
          keyString = key.toString();
        }
      }

      String? textValue;
      if (widget is Text) {
        textValue = widget.data;
      } else if (widget is RichText) {
        textValue = widget.text.toPlainText();
      }

      final isTextField = widget is TextField;
      final hasKey = keyString != null;
      final isText = textValue != null && textValue.trim().isNotEmpty;

      if (hasKey || isTextField || isText) {
        final Map<String, dynamic> data = {
          'type': widget.runtimeType.toString(),
        };
        if (keyString != null) data['key'] = keyString;
        if (textValue != null && textValue.trim().isNotEmpty) {
          data['text'] = textValue;
        }

        if (widget is TextField) {
          data['hint'] = widget.decoration?.hintText;
          data['text'] = widget.controller?.text;
        }

        widgets.add(data);
      }

      element.visitChildren(walk);
    }

    try {
      final root = WidgetsBinding.instance.rootElement;
      if (root != null) {
        walk(root);
      }
      return developer.ServiceExtensionResponse.result(
        json.encode({
          'status': 'ok',
          'elements': widgets,
        }),
      );
    } catch (e, stack) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        json.encode({'error': e.toString(), 'stack': stack.toString()}),
      );
    }
  });

  app.main();
}
