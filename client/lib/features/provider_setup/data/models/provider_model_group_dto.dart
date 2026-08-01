import 'model_options_dto.dart';

/// A provider group in the hierarchical model picker: one configured provider
/// plus its available models.
class ProviderModelGroupDto {
  final String providerId;
  final String displayName;
  final bool runtimeReady;
  final ModelOptionsDto models;
  final bool liveFetchFailed;

  ProviderModelGroupDto({
    required this.providerId,
    required this.displayName,
    required this.runtimeReady,
    required this.models,
    this.liveFetchFailed = false,
  });

  factory ProviderModelGroupDto.fromJson(Map<String, dynamic> json) {
    return ProviderModelGroupDto(
      providerId: json['provider_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      runtimeReady: json['runtime_ready'] as bool? ?? false,
      models: ModelOptionsDto.fromJson(
        json['models'] as Map<String, dynamic>? ?? const {},
      ),
      liveFetchFailed: json['live_fetch_failed'] as bool? ?? false,
    );
  }
}
