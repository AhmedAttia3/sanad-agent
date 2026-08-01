/// Parsed entry in the `options` array returned by `model.options`.
class ModelOptionsDto {
  final String providerId;
  final List<String> models;
  final String? selectedModel;
  final bool authenticated;
  final String authType;
  final String? keyEnv;
  final String? warning;
  final String source;

  const ModelOptionsDto({
    required this.providerId,
    required this.models,
    this.selectedModel,
    required this.authenticated,
    required this.authType,
    this.keyEnv,
    this.warning,
    required this.source,
  });

  factory ModelOptionsDto.fromJson(Map<String, dynamic> json) {
    final models = (json['models'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ModelOptionsDto(
      providerId: (json['provider_id'] ?? '').toString(),
      models: models,
      selectedModel: json['selected_model']?.toString(),
      authenticated: (json['authenticated'] as bool?) ?? false,
      authType: (json['auth_type'] ?? 'api_key').toString(),
      keyEnv: json['key_env']?.toString(),
      warning: json['warning']?.toString(),
      source: (json['source'] ?? 'fallback').toString(),
    );
  }

  String? get recommendedModel => selectedModel ?? (models.isNotEmpty ? models.first : null);
}
