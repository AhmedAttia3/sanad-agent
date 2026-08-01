import '../../capabilities/models/tool_schema.dart';
import 'provider_profile.dart';

/// Provider-specific wire policy for Responses-compatible transports.
///
/// Protocol conversion stays in the codec; endpoint quirks stay here so they
/// never leak into the provider-neutral runner or BaseOpenAIAdapter.
class CodexResponsesPolicy {
  final bool sanitizeSlashEnums;

  const CodexResponsesPolicy._({required this.sanitizeSlashEnums});

  factory CodexResponsesPolicy.forProfile(ProviderProfile profile) {
    return CodexResponsesPolicy._(
      sanitizeSlashEnums: profile.name == 'xai-oauth',
    );
  }

  List<ToolSchema>? normalizeTools(List<ToolSchema>? tools) {
    if (!sanitizeSlashEnums || tools == null || tools.isEmpty) return tools;
    return tools
        .map(
          (tool) => ToolSchema(
            name: tool.name,
            description: tool.description,
            parameters: _sanitizeMap(tool.parameters),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (entry.key == 'enum' && entry.value is List) {
        final values = (entry.value as List)
            .where((value) => value is! String || !value.contains('/'))
            .toList(growable: false);
        if (values.isNotEmpty) result[entry.key] = values;
        continue;
      }
      result[entry.key] = _sanitizeValue(entry.value);
    }
    return result;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is Map) {
      return _sanitizeMap(value.map((key, nested) => MapEntry('$key', nested)));
    }
    if (value is List) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    return value;
  }
}
