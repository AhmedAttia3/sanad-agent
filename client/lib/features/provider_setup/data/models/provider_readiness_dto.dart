/// Parsed response of `provider.setup_status` and `provider.runtime_check`.
///
/// `configured` (setup data exists) is separated from `runtime_ready`
/// (credentials + model resolvable) per Plan 19.
class ProviderReadinessDto {
  final bool hasProvider;
  final bool runtimeReady;
  final String? activeProvider;
  final String? activeModel;
  final String? reason;

  const ProviderReadinessDto({
    required this.hasProvider,
    required this.runtimeReady,
    this.activeProvider,
    this.activeModel,
    this.reason,
  });

  factory ProviderReadinessDto.fromJson(Map<String, dynamic> json) {
    return ProviderReadinessDto(
      hasProvider: (json['has_provider'] as bool?) ?? false,
      runtimeReady: (json['runtime_ready'] as bool?) ?? false,
      activeProvider: json['active_provider']?.toString(),
      activeModel: json['active_model']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'has_provider': hasProvider,
    'runtime_ready': runtimeReady,
    if (activeProvider != null) 'active_provider': activeProvider,
    if (activeModel != null) 'active_model': activeModel,
    if (reason != null) 'reason': reason,
  };
}
