// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LLMProviderState _$LLMProviderStateFromJson(Map<String, dynamic> json) =>
    LLMProviderState(
      namespace: json['namespace'] as String,
      issuer: json['issuer'] as String?,
      data: json['data'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$LLMProviderStateToJson(LLMProviderState instance) =>
    <String, dynamic>{
      'namespace': instance.namespace,
      'issuer': instance.issuer,
      'data': instance.data,
    };
