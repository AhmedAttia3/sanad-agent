import 'dart:convert';

class SkillFrontmatter {
  final String? name;
  final String? description;
  final List<String> instructions;
  final List<String> activationRules;
  final List<String> preferredTools;
  final List<String> blockedTools;
  final bool? requiresApproval;
  final Map<String, dynamic> raw;

  const SkillFrontmatter({
    this.name,
    this.description,
    this.instructions = const [],
    this.activationRules = const [],
    this.preferredTools = const [],
    this.blockedTools = const [],
    this.requiresApproval,
    this.raw = const {},
  });

  factory SkillFrontmatter.parse(String contents) {
    final frontmatter = _parseFrontmatterMap(contents);
    if (frontmatter.isEmpty) {
      return const SkillFrontmatter();
    }

    return SkillFrontmatter(
      name: _stringValue(frontmatter['name']),
      description: _stringValue(frontmatter['description']),
      instructions: _stringListValue(frontmatter['instructions']),
      activationRules: _stringListValue(frontmatter['activation_rules']),
      preferredTools: _stringListValue(frontmatter['preferred_tools']),
      blockedTools: _stringListValue(frontmatter['blocked_tools']),
      requiresApproval: _boolValue(frontmatter['requires_approval']),
      raw: frontmatter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (instructions.isNotEmpty) 'instructions': instructions,
      if (activationRules.isNotEmpty) 'activation_rules': activationRules,
      if (preferredTools.isNotEmpty) 'preferred_tools': preferredTools,
      if (blockedTools.isNotEmpty) 'blocked_tools': blockedTools,
      if (requiresApproval != null) 'requires_approval': requiresApproval,
      if (raw.isNotEmpty) 'raw': raw,
    };
  }

  static Map<String, dynamic> _parseFrontmatterMap(String contents) {
    final lines = const LineSplitter().convert(contents);
    if (lines.isEmpty || lines.first.trim() != '---') {
      return const {};
    }

    final frontmatterLines = <String>[];
    for (final line in lines.skip(1)) {
      if (line.trim() == '---') {
        break;
      }
      frontmatterLines.add(line);
    }

    if (frontmatterLines.isEmpty) {
      return const {};
    }

    final result = <String, dynamic>{};
    String? currentKey;
    List<String>? currentList;

    void commitList() {
      if (currentKey == null || currentList == null) {
        return;
      }
      result[currentKey!] = List<String>.unmodifiable(currentList!);
      currentKey = null;
      currentList = null;
    }

    for (final rawLine in frontmatterLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      if (currentKey != null && trimmed.startsWith('-')) {
        currentList!.add(_unquote(trimmed.substring(1).trim()));
        continue;
      }

      commitList();

      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }

      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (value.isEmpty) {
        currentKey = key;
        currentList = <String>[];
        continue;
      }

      result[key] = _parseScalar(value);
    }

    commitList();
    return Map<String, dynamic>.unmodifiable(result);
  }

  static dynamic _parseScalar(String value) {
    final normalized = _unquote(value);
    final lower = normalized.toLowerCase();
    if (lower == 'true') {
      return true;
    }
    if (lower == 'false') {
      return false;
    }
    return normalized;
  }

  static String _unquote(String value) {
    return value.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
  }

  static String? _stringValue(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _stringListValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : <String>[trimmed];
    }
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static bool? _boolValue(dynamic value) {
    return value is bool ? value : null;
  }
}

class SkillFrontmatterMetadata {
  final Map<String, dynamic> json;

  const SkillFrontmatterMetadata(this.json);

  Map<String, dynamic> toJson() => json;
}
