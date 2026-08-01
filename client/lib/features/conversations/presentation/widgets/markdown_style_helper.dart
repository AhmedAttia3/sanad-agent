import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;
import 'package:sanad_client/core/theme/app_color_scheme.dart';

/// Centralized helper for generating consistent Markdown style sheets and
/// element builders across conversation widgets (e.g. UserMessageTile, EventTile).
class MarkdownStyleHelper {
  /// Builds a [MarkdownStyleSheet] configured with the app's standard typography and colors.
  static MarkdownStyleSheet getStyleSheet(
    BuildContext context, {
    bool isFinal = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final codeColor = theme.colorScheme.codeColor;

    return MarkdownStyleSheet(
      p: GoogleFonts.roboto(
        color: isFinal ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      code: GoogleFonts.firaCode(
        color: codeColor,
        fontSize: 13,
        height: 1.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      blockquote: GoogleFonts.roboto(
        color: isDark ? theme.colorScheme.onSurface.withValues(alpha: 0.9) : theme.colorScheme.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: codeColor.withValues(alpha: 0.4),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
    );
  }
}

/// Custom builder for inline code and multiline fallback blocks in Markdown text.
class AppInlineCodeBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  AppInlineCodeBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.contains('\n')) {
      final theme = Theme.of(context);
      final codeColor = theme.colorScheme.codeColor;

      String codeText = text;
      if (codeText.endsWith('\n')) {
        codeText = codeText.substring(0, codeText.length - 1);
      }

      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            codeText,
            textDirection: TextDirection.ltr,
            style: GoogleFonts.firaCode(
              color: codeColor,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.8)
        : theme.colorScheme.surfaceContainer.withValues(alpha: 0.5);

    final borderColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.6)
        : theme.colorScheme.outline.withValues(alpha: 0.3);

    final textColor = theme.colorScheme.codeColor;
    const fontSize = 12.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          text,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.firaCode(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
