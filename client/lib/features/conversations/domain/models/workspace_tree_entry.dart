class WorkspaceTreeEntry {
  final String name;
  final String path;
  final String relativePath;
  final bool isDirectory;
  final int size;
  final DateTime? modifiedAt;

  const WorkspaceTreeEntry({
    required this.name,
    required this.path,
    required this.relativePath,
    required this.isDirectory,
    this.size = 0,
    this.modifiedAt,
  });

  factory WorkspaceTreeEntry.fromJson(Map<String, dynamic> json) {
    return WorkspaceTreeEntry(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      relativePath: json['relative_path']?.toString() ?? '',
      isDirectory: json['type']?.toString() == 'directory',
      size: int.tryParse(json['size']?.toString() ?? '') ?? 0,
      modifiedAt: DateTime.tryParse(json['modified_at']?.toString() ?? ''),
    );
  }
}
