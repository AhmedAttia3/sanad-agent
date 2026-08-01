import 'package:json_annotation/json_annotation.dart';
import 'message.dart';
import 'llm_finish_reason.dart';

export 'llm_finish_reason.dart';

part 'agent_response.g.dart';

@JsonSerializable(explicitToJson: true)
class AgentResponse {
  final Message message;
  final bool isToolCall;
  final Map<String, dynamic>? usage;
  final String? model;
  final String? provider;
  @JsonKey(
    defaultValue: LLMFinishReason.unknown,
    unknownEnumValue: LLMFinishReason.unknown,
  )
  final LLMFinishReason finishReason;

  AgentResponse({
    required this.message,
    this.isToolCall = false,
    this.usage,
    this.model,
    this.provider,
    this.finishReason = LLMFinishReason.unknown,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) =>
      _$AgentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AgentResponseToJson(this);
}
