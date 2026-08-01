import 'dart:convert';

import 'codex_responses_codec.dart';

class CodexStreamDelta {
  final String? content;
  final String? thought;
  final String? reasoning;

  const CodexStreamDelta({this.content, this.thought, this.reasoning});

  bool get isEmpty => content == null && thought == null && reasoning == null;
}

class CodexResponsesSseAccumulator {
  final Map<int, Map<String, dynamic>> _items = {};
  final Map<String, int> _itemIndexes = {};
  Map<String, dynamic>? _terminalResponse;
  bool _done = false;
  bool _sawTerminalEvent = false;
  String? _lastThoughtItem;
  String? _lastReasoningSummaryPart;

  bool get isDone => _done;
  bool get sawTerminalEvent => _sawTerminalEvent;

  CodexStreamDelta addDataLine(String rawData) {
    final data = rawData.trim();
    if (data == '[DONE]') {
      _done = true;
      return const CodexStreamDelta();
    }
    final decoded = jsonDecode(data);
    final event = _map(decoded);
    if (event == null) {
      throw const FormatException('Responses SSE data must be a JSON object.');
    }
    return addEvent(event);
  }

  CodexStreamDelta addEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString();
    if (type == 'error') {
      final error = _map(event['error']);
      throw CodexResponsesException(
        'Failed to generate stream: ${error?['message']?.toString() ?? event['message']?.toString() ?? 'Unknown Responses stream error.'}',
        code: error?['code']?.toString(),
      );
    }

    switch (type) {
      case 'response.output_item.added':
        _storeItem(event, replace: false);
      case 'response.output_item.done':
        _storeItem(event, replace: true);
      case 'response.output_text.delta':
        final delta = event['delta']?.toString();
        if (delta == null || delta.isEmpty) return const CodexStreamDelta();
        final item = _ensureItem(event, type: 'message');
        final part = _ensureContentPart(item, event, type: 'output_text');
        part['text'] = '${part['text'] ?? ''}$delta';
        final phase = item['phase']?.toString().toLowerCase();
        if (phase == 'commentary') {
          final itemKey = '${event['output_index'] ?? event['item_id'] ?? 0}';
          final separator =
              _lastThoughtItem != null && _lastThoughtItem != itemKey
              ? '\n\n'
              : '';
          _lastThoughtItem = itemKey;
          return CodexStreamDelta(thought: '$separator$delta');
        }
        return phase == 'analysis'
            ? CodexStreamDelta(reasoning: delta)
            : CodexStreamDelta(content: delta);
      case 'response.output_text.done':
        final text = event['text']?.toString();
        if (text != null) {
          final item = _ensureItem(event, type: 'message');
          _ensureContentPart(item, event, type: 'output_text')['text'] = text;
        }
      case 'response.reasoning_summary_text.delta':
        final delta = event['delta']?.toString();
        if (delta == null || delta.isEmpty) return const CodexStreamDelta();
        final item = _ensureItem(event, type: 'reasoning');
        final part = _ensureSummaryPart(item, event);
        final partKey =
            '${event['output_index'] ?? 0}:${event['summary_index'] ?? 0}';
        final separator =
            _lastReasoningSummaryPart != null &&
                _lastReasoningSummaryPart != partKey
            ? '\n\n'
            : '';
        _lastReasoningSummaryPart = partKey;
        part['text'] = '${part['text'] ?? ''}$delta';
        return CodexStreamDelta(reasoning: '$separator$delta');
      case 'response.reasoning_summary_text.done':
        final text = event['text']?.toString();
        if (text != null) {
          final item = _ensureItem(event, type: 'reasoning');
          _ensureSummaryPart(item, event)['text'] = text;
        }
      case 'response.function_call_arguments.delta':
        final delta = event['delta']?.toString();
        if (delta != null) {
          final item = _ensureItem(event, type: 'function_call');
          item['arguments'] = '${item['arguments'] ?? ''}$delta';
        }
      case 'response.function_call_arguments.done':
        final arguments = event['arguments']?.toString();
        if (arguments != null) {
          _ensureItem(event, type: 'function_call')['arguments'] = arguments;
        }
      case 'response.completed':
      case 'response.incomplete':
      case 'response.failed':
      case 'response.cancelled':
        final response = _map(event['response']);
        if (response == null) {
          throw FormatException('$type event is missing response.');
        }
        _terminalResponse = Map<String, dynamic>.from(response);
        _sawTerminalEvent = true;
        _done = true;
    }
    return const CodexStreamDelta();
  }

  Map<String, dynamic> buildResponse({required String fallbackModel}) {
    final response = Map<String, dynamic>.from(
      _terminalResponse ??
          <String, dynamic>{'status': 'completed', 'model': fallbackModel},
    );
    final output = response['output'];
    if (output is! List || output.isEmpty) {
      response['output'] = [
        for (final entry
            in _items.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
          entry.value,
      ];
    }
    response['model'] ??= fallbackModel;
    response['status'] ??= _sawTerminalEvent ? 'completed' : 'completed';
    return response;
  }

  void _storeItem(Map<String, dynamic> event, {required bool replace}) {
    final item = _map(event['item']);
    if (item == null) {
      throw const FormatException('Responses output item event is malformed.');
    }
    final index = _eventIndex(event, item);
    if (replace || !_items.containsKey(index)) {
      final existing = _items[index];
      final replacement = _deepCopy(item);
      if (replacement['arguments']?.toString().isEmpty == true &&
          existing?['arguments'] != null) {
        replacement['arguments'] = existing!['arguments'];
      }
      _items[index] = replacement;
    } else {
      _items[index]!.addAll(_deepCopy(item));
    }
    final id = item['id']?.toString();
    if (id?.isNotEmpty == true) _itemIndexes[id!] = index;
  }

  Map<String, dynamic> _ensureItem(
    Map<String, dynamic> event, {
    required String type,
  }) {
    final index = _eventIndex(event, null);
    final item = _items.putIfAbsent(index, () => {'type': type});
    item['type'] ??= type;
    final itemId = event['item_id']?.toString();
    if (itemId?.isNotEmpty == true) {
      item['id'] ??= itemId;
      _itemIndexes[itemId!] = index;
    }
    return item;
  }

  Map<String, dynamic> _ensureContentPart(
    Map<String, dynamic> item,
    Map<String, dynamic> event, {
    required String type,
  }) {
    item['role'] ??= 'assistant';
    final content = item.putIfAbsent('content', () => <dynamic>[]) as List;
    final index = (event['content_index'] as num?)?.toInt() ?? 0;
    while (content.length <= index) {
      content.add(<String, dynamic>{'type': type, 'text': ''});
    }
    final part = _map(content[index]) ?? <String, dynamic>{};
    part['type'] ??= type;
    content[index] = part;
    return part;
  }

  Map<String, dynamic> _ensureSummaryPart(
    Map<String, dynamic> item,
    Map<String, dynamic> event,
  ) {
    final summary = item.putIfAbsent('summary', () => <dynamic>[]) as List;
    final index = (event['summary_index'] as num?)?.toInt() ?? 0;
    while (summary.length <= index) {
      summary.add(<String, dynamic>{'type': 'summary_text', 'text': ''});
    }
    final part = _map(summary[index]) ?? <String, dynamic>{};
    part['type'] ??= 'summary_text';
    summary[index] = part;
    return part;
  }

  int _eventIndex(Map<String, dynamic> event, Map<String, dynamic>? item) {
    final explicit = (event['output_index'] as num?)?.toInt();
    if (explicit != null) return explicit;
    final itemId = event['item_id']?.toString() ?? item?['id']?.toString();
    if (itemId != null && _itemIndexes.containsKey(itemId)) {
      return _itemIndexes[itemId]!;
    }
    return _items.isEmpty ? 0 : _items.keys.reduce((a, b) => a > b ? a : b) + 1;
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
      (jsonDecode(jsonEncode(value)) as Map).map(
        (key, value) => MapEntry('$key', value),
      );

  static Map<String, dynamic>? _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((key, value) => MapEntry('$key', value));
    return null;
  }
}
