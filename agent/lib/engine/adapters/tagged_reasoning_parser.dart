class TaggedReasoningText {
  final String? content;
  final String? reasoning;

  const TaggedReasoningText({this.content, this.reasoning});
}

const _reasoningMarkers = [
  ('<thought>', '</thought>'),
  ('<think>', '</think>'),
  ('<reasoning>', '</reasoning>'),
  ('<thinking>', '</thinking>'),
  ('[THOUGHT]', '[/THOUGHT]'),
  ('<mm:think>', '</mm:think>'),
];

TaggedReasoningText splitTaggedReasoning(String content) {
  for (final markers in _reasoningMarkers) {
    final start = content.indexOf(markers.$1);
    final end = content.indexOf(markers.$2, start < 0 ? 0 : start);
    if (start >= 0 && end >= start) {
      return TaggedReasoningText(
        content:
            '${content.substring(0, start)}${content.substring(end + markers.$2.length)}'
                .trim(),
        reasoning: content.substring(start + markers.$1.length, end).trim(),
      );
    }
  }
  return TaggedReasoningText(content: content);
}

/// Separates a possible leading tagged reasoning block across arbitrary stream
/// chunk boundaries. Untagged streams pass through immediately; tagged streams
/// buffer only an undecided opening marker or a possible split closing marker.
class TaggedReasoningStreamParser {
  final StringBuffer _buffer = StringBuffer();
  (String, String)? _activeMarkers;
  bool _isPlainContent = false;
  bool _isPostTagContent = false;

  TaggedReasoningText add(String chunk) {
    if (_isPlainContent || _isPostTagContent) {
      return TaggedReasoningText(content: chunk);
    }

    if (_activeMarkers case final markers?) {
      return _consumeReasoning(chunk, markers.$2);
    }

    _buffer.write(chunk);
    final buffered = _buffer.toString();
    final candidate = buffered.trimLeft();

    for (final markers in _reasoningMarkers) {
      if (!candidate.startsWith(markers.$1)) continue;
      _activeMarkers = markers;
      final openingIndex = buffered.indexOf(markers.$1);
      final remainder = buffered.substring(openingIndex + markers.$1.length);
      _buffer.clear();
      return _consumeReasoning(remainder, markers.$2);
    }

    final isPossibleOpening = _reasoningMarkers.any(
      (markers) => markers.$1.startsWith(candidate),
    );
    if (isPossibleOpening) return const TaggedReasoningText();

    _isPlainContent = true;
    _buffer.clear();
    return TaggedReasoningText(content: buffered);
  }

  TaggedReasoningText _consumeReasoning(String chunk, String closingMarker) {
    _buffer.write(chunk);
    final buffered = _buffer.toString();
    final closingIndex = buffered.indexOf(closingMarker);
    if (closingIndex >= 0) {
      final reasoning = buffered.substring(0, closingIndex);
      final content = buffered.substring(closingIndex + closingMarker.length);
      _buffer.clear();
      _isPostTagContent = true;
      return TaggedReasoningText(
        reasoning: reasoning.isEmpty ? null : reasoning,
        content: content.isEmpty ? null : content,
      );
    }

    final heldSuffixLength = _possibleClosingSuffixLength(
      buffered,
      closingMarker,
    );
    final confirmedLength = buffered.length - heldSuffixLength;
    if (confirmedLength == 0) return const TaggedReasoningText();

    final reasoning = buffered.substring(0, confirmedLength);
    final heldSuffix = buffered.substring(confirmedLength);
    _buffer.clear();
    _buffer.write(heldSuffix);
    return TaggedReasoningText(reasoning: reasoning);
  }

  int _possibleClosingSuffixLength(String value, String closingMarker) {
    final maxLength = value.length < closingMarker.length - 1
        ? value.length
        : closingMarker.length - 1;
    for (var length = maxLength; length > 0; length--) {
      if (closingMarker.startsWith(value.substring(value.length - length))) {
        return length;
      }
    }
    return 0;
  }

  TaggedReasoningText finish() {
    if (_buffer.isEmpty) return const TaggedReasoningText();
    final buffered = _buffer.toString();
    _buffer.clear();
    if (_activeMarkers != null) {
      return TaggedReasoningText(reasoning: buffered);
    }
    return TaggedReasoningText(content: buffered);
  }
}
