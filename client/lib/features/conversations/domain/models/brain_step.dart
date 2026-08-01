enum BrainStepType {
  user,
  answer,
  tool,
  info,
  error,
  plan,
}

class BrainStep {
  final String id;
  final BrainStepType type;
  String title;
  final String? subtitle;
  final dynamic input;
  dynamic output;
  String status; // running, completed, error, info, active
  List<Map<String, dynamic>>? tasks;
  final DateTime? timestamp;

  BrainStep({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    this.subtitle,
    this.input,
    this.output,
    this.tasks,
    this.timestamp,
  });
}
