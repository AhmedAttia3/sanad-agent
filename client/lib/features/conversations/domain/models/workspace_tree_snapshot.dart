import 'package:sanad_client/features/conversations/domain/models/workspace_tree_entry.dart';

class WorkspaceTreeSnapshot {
  final String workspaceId;
  final String rootPath;
  final String path;
  final String? parentPath;
  final List<WorkspaceTreeEntry> entries;
  final bool truncated;

  const WorkspaceTreeSnapshot({
    required this.workspaceId,
    required this.rootPath,
    required this.path,
    this.parentPath,
    required this.entries,
    required this.truncated,
  });

  factory WorkspaceTreeSnapshot.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List? ?? const [];
    return WorkspaceTreeSnapshot(
      workspaceId: json['workspace_id']?.toString() ?? '',
      rootPath: json['root_path']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      parentPath: json['parent_path']?.toString(),
      entries: rawEntries
          .whereType<Map>()
          .map((entry) => WorkspaceTreeEntry.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false),
      truncated: json['truncated'] == true,
    );
  }
}
