import 'package:json_annotation/json_annotation.dart';

part 'llm_provider_state.g.dart';

/// Opaque, JSON-safe state owned by one LLM adapter namespace.
///
/// [issuer] identifies the provider endpoint or instance that minted the state
/// when replaying it against another issuer would be invalid.
@JsonSerializable()
class LLMProviderState {
  final String namespace;
  final String? issuer;
  final Map<String, dynamic> data;

  const LLMProviderState({
    required this.namespace,
    this.issuer,
    required this.data,
  });

  factory LLMProviderState.fromJson(Map<String, dynamic> json) =>
      _$LLMProviderStateFromJson(json);

  Map<String, dynamic> toJson() => _$LLMProviderStateToJson(this);
}
