// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentResponse _$AgentResponseFromJson(Map<String, dynamic> json) =>
    AgentResponse(
      message: Message.fromJson(json['message'] as Map<String, dynamic>),
      isToolCall: json['isToolCall'] as bool? ?? false,
      usage: json['usage'] as Map<String, dynamic>?,
      model: json['model'] as String?,
      provider: json['provider'] as String?,
      finishReason:
          $enumDecodeNullable(
            _$LLMFinishReasonEnumMap,
            json['finishReason'],
            unknownValue: LLMFinishReason.unknown,
          ) ??
          LLMFinishReason.unknown,
    );

Map<String, dynamic> _$AgentResponseToJson(AgentResponse instance) =>
    <String, dynamic>{
      'message': instance.message.toJson(),
      'isToolCall': instance.isToolCall,
      'usage': instance.usage,
      'model': instance.model,
      'provider': instance.provider,
      'finishReason': _$LLMFinishReasonEnumMap[instance.finishReason]!,
    };

const _$LLMFinishReasonEnumMap = {
  LLMFinishReason.stop: 'stop',
  LLMFinishReason.toolCalls: 'toolCalls',
  LLMFinishReason.incomplete: 'incomplete',
  LLMFinishReason.length: 'length',
  LLMFinishReason.failed: 'failed',
  LLMFinishReason.cancelled: 'cancelled',
  LLMFinishReason.unknown: 'unknown',
};
