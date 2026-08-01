import 'package:json_annotation/json_annotation.dart';
import 'tool_call.dart';
import 'llm_provider_state.dart';
import 'llm_finish_reason.dart';

part 'message.g.dart';

enum MessageRole { system, user, assistant, tool }

@JsonSerializable(explicitToJson: true)
class Message {
  final MessageRole role;
  final String? content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? thought;
  final String? reasoning;

  /// Opaque, adapter-owned state required for provider protocol continuity.
  ///
  /// This is deliberately separate from user-visible [reasoning]. Keys must be
  /// namespaced by the owning adapter and are persisted with message history.
  final LLMProviderState? providerState;

  /// Provider-neutral terminal classification persisted with conversation
  /// history so continuation decisions survive process restarts.
  @JsonKey(
    defaultValue: LLMFinishReason.unknown,
    unknownEnumValue: LLMFinishReason.unknown,
  )
  final LLMFinishReason finishReason;

  /// Per-turn metrics persisted alongside this message (usage, model, provider, context_tokens, runtime_ms).
  final Map<String, dynamic>? metadata;

  Message({
    required this.role,
    this.content,
    this.toolCalls,
    this.toolCallId,
    this.thought,
    this.reasoning,
    this.providerState,
    this.finishReason = LLMFinishReason.unknown,
    this.metadata,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  Message copyWith({
    MessageRole? role,
    String? content,
    List<ToolCall>? toolCalls,
    String? toolCallId,
    String? thought,
    String? reasoning,
    LLMProviderState? providerState,
    bool clearProviderState = false,
    LLMFinishReason? finishReason,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      role: role ?? this.role,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      toolCallId: toolCallId ?? this.toolCallId,
      thought: thought ?? this.thought,
      reasoning: reasoning ?? this.reasoning,
      providerState: clearProviderState
          ? null
          : providerState ?? this.providerState,
      finishReason: finishReason ?? this.finishReason,
      metadata: metadata ?? this.metadata,
    );
  }
}
