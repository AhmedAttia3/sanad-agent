import 'skill_definition.dart';
import 'skill_frontmatter.dart';

class SkillInventoryEntry {
  final String name;
  final String? description;
  final String path;
  final SkillOrigin origin;
  final SkillFrontmatterMetadata metadata;
  final bool active;
  final SkillShadowedBy? shadowedBy;

  const SkillInventoryEntry({
    required this.name,
    required this.path,
    required this.origin,
    required this.metadata,
    required this.active,
    this.description,
    this.shadowedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'path': path,
      'origin': origin.toJson(),
      'metadata': metadata.toJson(),
      'active': active,
      'shadowed_by': shadowedBy?.toJson(),
    };
  }
}

class SkillShadowedBy {
  final String name;
  final String path;
  final SkillOrigin origin;

  const SkillShadowedBy({
    required this.name,
    required this.path,
    required this.origin,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'path': path, 'origin': origin.toJson()};
  }
}

class SkillInventoryReport {
  final List<SkillInventoryEntry> skills;
  final String? workspacePath;
  final bool includeShadowed;

  const SkillInventoryReport({
    required this.skills,
    required this.includeShadowed,
    this.workspacePath,
  });

  Map<String, dynamic> toJson() {
    final active = skills.where((skill) => skill.active).length;
    return {
      'kind': 'skills',
      'action': 'list',
      'workspace_path': workspacePath,
      'include_shadowed': includeShadowed,
      'summary': {
        'total': skills.length,
        'active': active,
        'shadowed': skills.length - active,
      },
      'skills': skills.map((skill) => skill.toJson()).toList(growable: false),
    };
  }
}

class SkillRefreshReport extends SkillInventoryReport {
  const SkillRefreshReport({
    required super.skills,
    required super.includeShadowed,
    super.workspacePath,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['action'] = 'refresh';
    return json;
  }
}
