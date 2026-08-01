import 'package:json_annotation/json_annotation.dart';
import 'llm_provider_state.dart';

part 'tool_call.g.dart';

@JsonSerializable(explicitToJson: true)
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  /// Opaque adapter-owned identifiers or signatures needed to replay this
  /// provider tool call without exposing them as generic tool arguments.
  final LLMProviderState? providerState;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.providerState,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
  Map<String, dynamic> toJson() => _$ToolCallToJson(this);
}
