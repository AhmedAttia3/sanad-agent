// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolCall _$ToolCallFromJson(Map<String, dynamic> json) => ToolCall(
  id: json['id'] as String,
  name: json['name'] as String,
  arguments: json['arguments'] as Map<String, dynamic>,
  providerState: json['providerState'] == null
      ? null
      : LLMProviderState.fromJson(
          json['providerState'] as Map<String, dynamic>,
        ),
);

Map<String, dynamic> _$ToolCallToJson(ToolCall instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'arguments': instance.arguments,
  'providerState': instance.providerState?.toJson(),
};
