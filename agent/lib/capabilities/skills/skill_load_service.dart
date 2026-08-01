import 'dart:convert';

import 'skill_registry.dart';

class SkillLoadService {
  final Map<String, String>? _environment;
  final SkillRegistry? _registry;

  const SkillLoadService({
    Map<String, String>? environment,
    SkillRegistry? registry,
  }) : _environment = environment,
       _registry = registry;

  Future<String> load({
    required String skill,
    String? args,
    String? workspacePath,
  }) async {
    final resolved =
        await (_registry ?? SkillRegistry(environment: _environment)).resolve(
          skill: skill,
          workspacePath: workspacePath,
        );
    if (resolved == null) {
      throw Exception('Unknown skill: ${skill.trim()}');
    }

    final payload = <String, dynamic>{
      'skill': skill,
      'path': resolved.sourcePath,
      if (resolved.description != null) 'description': resolved.description,
      'prompt': resolved.prompt,
      'origin': resolved.origin.toJson(),
    };

    final metadata = _compactMetadata(
      resolved.metadata.toJson(),
      name: resolved.name,
      description: resolved.description,
    );
    if (metadata.isNotEmpty) {
      payload['metadata'] = metadata;
    }

    if (resolved.shadowedMatches.isNotEmpty) {
      payload['shadowed_matches'] = resolved.shadowedMatches
          .map((match) => match.toSummaryJson())
          .toList(growable: false);
    }
    if (args != null && args.trim().isNotEmpty) {
      payload['args'] = args.trim();
    }

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, dynamic> _compactMetadata(
    Map<String, dynamic> metadata, {
    required String? name,
    required String? description,
  }) {
    final compact = Map<String, dynamic>.from(metadata);
    compact.remove('raw');
    if (compact['name'] == name) {
      compact.remove('name');
    }
    if (compact['description'] == description) {
      compact.remove('description');
    }
    return compact;
  }
}
