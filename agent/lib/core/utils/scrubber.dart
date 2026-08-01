/// A stateful scrubber for streaming text that may contain hidden tags like `<memory-context>`.
/// Inspired by the reference architecture's streaming context scrubber.
class StreamingScrubber {
  static const String openTag = '<memory-context>';
  static const String closeTag = '</memory-context>';

  bool _inSpan = false;
  String _buffer = '';

  /// Feed a chunk of text and return the visible portion.
  String feed(String text) {
    if (text.isEmpty) return '';

    _buffer += text;
    String output = '';

    while (_buffer.isNotEmpty) {
      if (_inSpan) {
        final closeIdx = _buffer.toLowerCase().indexOf(closeTag);
        if (closeIdx == -1) {
          // Check if the buffer ends with a partial close tag
          final held = _maxPartialSuffix(_buffer, closeTag);
          // Drop everything except the potential partial tag
          _buffer = _buffer.substring(_buffer.length - held);
          return output;
        }
        // Found close tag - skip content and tag
        _buffer = _buffer.substring(closeIdx + closeTag.length);
        _inSpan = false;
      } else {
        final openIdx = _buffer.toLowerCase().indexOf(openTag);
        if (openIdx == -1) {
          // No open tag - check for partial open tag at the end
          final held = _maxPartialSuffix(_buffer, openTag);
          if (held > 0) {
            output += _buffer.substring(0, _buffer.length - held);
            _buffer = _buffer.substring(_buffer.length - held);
          } else {
            output += _buffer;
            _buffer = '';
          }
          return output;
        }
        // Emit text before the tag, enter span
        output += _buffer.substring(0, openIdx);
        _buffer = _buffer.substring(openIdx + openTag.length);
        _inSpan = true;
      }
    }

    return output;
  }

  /// Clean any remaining text (e.g., regex-based for non-streaming).
  static String scrub(String text) {
    final regex = RegExp(
      r'<memory-context>[\s\S]*?</memory-context>',
      caseSensitive: false,
    );
    return text.replaceAll(regex, '').trim();
  }

  /// Helper to find the length of the longest suffix of [buf] that is a prefix of [tag].
  int _maxPartialSuffix(String buf, String tag) {
    final bufLower = buf.toLowerCase();
    final tagLower = tag.toLowerCase();
    final maxCheck = bufLower.length < tagLower.length
        ? bufLower.length
        : tagLower.length - 1;

    for (int i = maxCheck; i > 0; i--) {
      if (tagLower.startsWith(bufLower.substring(bufLower.length - i))) {
        return i;
      }
    }
    return 0;
  }
}
