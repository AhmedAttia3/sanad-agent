class DeviceWorkspace {
  final String id;
  final String name;
  final String path;
  final String trustState;
  final String availability;

  const DeviceWorkspace({
    required this.id,
    required this.name,
    required this.path,
    this.trustState = 'untrusted',
    this.availability = 'available',
  });

  bool get isAvailable => availability == 'available';

  factory DeviceWorkspace.fromJson(Map<String, dynamic> json) {
    final path = (json['path'] ?? '').toString();
    final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
    final fallbackName = path.trim().isEmpty ? 'Workspace' : (segments.isEmpty ? path : segments.last);
    return DeviceWorkspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? fallbackName).toString(),
      path: path,
      trustState: (json['trust_state'] ?? 'untrusted').toString(),
      availability: (json['availability'] ?? (json['is_missing'] == true ? 'missing' : 'available')).toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceWorkspace &&
        other.id == id &&
        other.name == name &&
        other.path == path &&
        other.trustState == trustState &&
        other.availability == availability;
  }

  @override
  int get hashCode => Object.hash(id, name, path, trustState, availability);
}
