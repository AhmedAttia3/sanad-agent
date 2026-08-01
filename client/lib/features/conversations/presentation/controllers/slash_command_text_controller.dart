import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sanad_client/features/conversations/domain/models/slash_command_entry.dart';
import 'package:sanad_client/features/conversations/presentation/utils/skill_composer_utils.dart';

class SlashCommandDispatchToken {
  final SlashCommandEntry entry;
  final int start;
  final int end;

  const SlashCommandDispatchToken({
    required this.entry,
    required this.start,
    required this.end,
  });
}

class SlashCommandDispatchExport {
  final String plainText;
  final List<SlashCommandDispatchToken> tokens;

  const SlashCommandDispatchExport({
    required this.plainText,
    required this.tokens,
  });
}

class SlashCommandTextController extends TextEditingController {
  static const int _tokenCodePointStart = 0xE000;

  final Map<String, SlashCommandEntry> _tokensByMarker = <String, SlashCommandEntry>{};
  int _nextTokenCodePoint = _tokenCodePointStart;

  SlashCommandTextController();

  String exportPlainText() {
    return exportForDispatch().plainText;
  }

  SlashCommandDispatchExport exportForDispatch() {
    final buffer = StringBuffer();
    final tokens = <SlashCommandDispatchToken>[];
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final token = _tokensByMarker[character];
      if (token != null) {
        final start = buffer.length;
        buffer.write(token.insertText);
        tokens.add(
          SlashCommandDispatchToken(
            entry: token,
            start: start,
            end: buffer.length,
          ),
        );
      } else {
        buffer.write(character);
      }
    }
    return SlashCommandDispatchExport(
      plainText: buffer.toString(),
      tokens: tokens,
    );
  }

  TextEditingValue applySlashCommandSelection({
    required TextEditingValue value,
    required SkillSlashQuery query,
    required SlashCommandEntry entry,
  }) {
    final marker = _allocateTokenMarker(entry);
    final trailingSpacer = _needsTrailingSpacer(value, cursorIndex: query.cursorIndex) ? ' ' : '';
    final updatedText = value.text.replaceRange(
      query.slashIndex,
      query.cursorIndex,
      '$marker$trailingSpacer',
    );
    final selectionOffset = query.slashIndex + 1 + trailingSpacer.length;
    return value.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: selectionOffset),
      composing: TextRange.empty,
    );
  }

  @override
  set value(TextEditingValue newValue) {
    _pruneMissingTokens(newValue.text);
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveStyle = style ?? const TextStyle();
    final children = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) {
        return;
      }
      children.add(TextSpan(text: buffer.toString(), style: effectiveStyle));
      buffer.clear();
    }

    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final token = _tokensByMarker[character];
      if (token == null) {
        buffer.write(character);
        continue;
      }

      flush();
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(token.type.icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                token.command,
                style: GoogleFonts.inter(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    flush();
    return TextSpan(style: effectiveStyle, children: children);
  }

  String _allocateTokenMarker(SlashCommandEntry entry) {
    while (_nextTokenCodePoint <= 0xF8FF) {
      final marker = String.fromCharCode(_nextTokenCodePoint);
      _nextTokenCodePoint += 1;
      if (_tokensByMarker.containsKey(marker)) {
        continue;
      }
      _tokensByMarker[marker] = entry;
      return marker;
    }
    throw StateError('No slash command token markers are available.');
  }

  bool _needsTrailingSpacer(
    TextEditingValue value, {
    required int cursorIndex,
  }) {
    if (cursorIndex >= value.text.length) {
      return true;
    }
    return value.text[cursorIndex].trim().isNotEmpty;
  }

  void _pruneMissingTokens(String currentText) {
    final activeMarkers = currentText.runes.map(String.fromCharCode).where(_tokensByMarker.containsKey).toSet();
    _tokensByMarker.removeWhere((marker, _) => !activeMarkers.contains(marker));
  }
}
