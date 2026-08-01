import 'package:logging/logging.dart';
import '../core/models/message.dart';
import 'adapters/llm_adapter.dart';

class ContextEngine {
  final _logger = Logger('ContextEngine');
  final int maxTokens;
  final LLMAdapter? adapter;

  ContextEngine({this.maxTokens = 2000, this.adapter});

  /// Estimates the number of tokens in the history.
  /// A rough estimation: 4 characters per token.
  int estimateTokens(List<Message> history) {
    int total = 0;
    for (var msg in history) {
      if (msg.content != null) {
        total += msg.content!.length ~/ 4;
      }
      if (msg.toolCalls != null) {
        for (var call in msg.toolCalls!) {
          total += call.name.length ~/ 4;
          total += call.arguments.toString().length ~/ 4;
        }
      }
    }
    return total;
  }

  /// Compresses the history if it exceeds context limits.
  /// Returns a new list of messages with a summary of older messages.
  ///
  /// When [adapter] is provided it takes precedence over the constructor-injected
  /// adapter. This lets callers pass the **live** turn-scoped adapter (resolved
  /// from the current provider route) so compression never falls back to a
  /// stale singleton that was frozen before a provider was configured.
  Future<List<Message>> compressIfNeeded(
    List<Message> history, {
    LLMAdapter? adapter,
  }) async {
    final effectiveAdapter = adapter ?? this.adapter;
    final currentLimit = effectiveAdapter != null
        ? await effectiveAdapter.getContextLimit()
        : maxTokens;

    if (estimateTokens(history) <= currentLimit) {
      return history;
    }

    if (effectiveAdapter == null) {
      // If no adapter, just truncate (fallback)
      if (history.length > 5) {
        return [history.first, ...history.sublist(history.length - 4)];
      }
      return history;
    }

    // Summarization logic
    // We keep the system message (if any) and the last few messages
    final systemMessages = history
        .where((m) => m.role == MessageRole.system)
        .toList();
    final recentMessages = history.length > 10
        ? history.sublist(history.length - 10)
        : history;

    // The messages to be summarized are those not in recentMessages and not system messages
    final toSummarize = history
        .where(
          (m) => !systemMessages.contains(m) && !recentMessages.contains(m),
        )
        .toList();

    if (toSummarize.isEmpty) return history;

    final summaryPrompt = [
      Message(
        role: MessageRole.system,
        content:
            'Summarize the following conversation history concisely while preserving key facts and context:',
      ),
      ...toSummarize,
    ];

    try {
      _logger.info(
        'Compressing context (Estimated tokens: ${estimateTokens(history)})...',
      );
      final response = await effectiveAdapter.generateResponse(summaryPrompt);
      final summary = response.message.content ?? 'Summary unavailable.';

      final compressedHistory = [
        ...systemMessages,
        Message(
          role: MessageRole.system,
          content: 'Previous conversation summary: $summary',
        ),
        ...recentMessages,
      ];

      _logger.info('Context compressed successfully.');
      return compressedHistory;
    } catch (e) {
      _logger.severe('Context compression failed: $e');
      return history; // Return original on error
    }
  }
}
