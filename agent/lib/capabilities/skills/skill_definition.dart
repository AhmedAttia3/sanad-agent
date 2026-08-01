import 'skill_frontmatter.dart';

class SkillDefinition {
  final String requestedSkill;
  final String sourcePath;
  final String prompt;
  final String? name;
  final String? description;
  final SkillFrontmatter metadata;
  final SkillOrigin origin;
  final List<SkillMatch> shadowedMatches;

  const SkillDefinition({
    required this.requestedSkill,
    required this.sourcePath,
    required this.prompt,
    required this.metadata,
    required this.origin,
    this.name,
    this.description,
    this.shadowedMatches = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'requested_skill': requestedSkill,
      'path': sourcePath,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      'metadata': metadata.toJson(),
      'prompt': prompt,
      'origin': origin.toJson(),
      if (shadowedMatches.isNotEmpty)
        'shadowed_matches': shadowedMatches
            .map((match) => match.toSummaryJson())
            .toList(growable: false),
    };
  }
}

extension SkillFrontmatterJson on SkillFrontmatter {
  SkillFrontmatterMetadata toMetadata() => SkillFrontmatterMetadata(toJson());
}

class SkillOrigin {
  final String rootPath;
  final String filePath;
  final SkillSourceScope scope;
  final SkillRootKind rootKind;
  final int precedence;

  const SkillOrigin({
    required this.rootPath,
    required this.filePath,
    required this.scope,
    required this.rootKind,
    required this.precedence,
  });

  Map<String, dynamic> toJson() {
    return {
      'root_path': rootPath,
      'file_path': filePath,
      'scope': scope.name,
      'root_kind': rootKind.name,
      'precedence': precedence,
    };
  }
}

class SkillMatch {
  final String sourcePath;
  final String prompt;
  final String? name;
  final String? description;
  final SkillFrontmatter metadata;
  final SkillOrigin origin;

  const SkillMatch({
    required this.sourcePath,
    required this.prompt,
    required this.metadata,
    required this.origin,
    this.name,
    this.description,
  });

  SkillDefinition toDefinition({
    required String requestedSkill,
    List<SkillMatch> shadowedMatches = const [],
  }) {
    return SkillDefinition(
      requestedSkill: requestedSkill,
      sourcePath: sourcePath,
      prompt: prompt,
      name: name,
      description: description,
      metadata: metadata,
      origin: origin,
      shadowedMatches: shadowedMatches,
    );
  }

  Map<String, dynamic> toSummaryJson() {
    return {
      'path': sourcePath,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      'metadata': metadata.toJson(),
      'origin': origin.toJson(),
    };
  }
}

enum SkillSourceScope { workspace, user }

enum SkillRootKind {
  sanadSkills,
  sanadLegacyCommands,
  agentSkills,
  agentsSkills,
  codexSkills,
  codexLegacyCommands,
  claudeSkills,
  claudeOmcLearnedSkills,
  claudeLegacyCommands,
}
