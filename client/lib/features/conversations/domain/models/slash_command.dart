class SlashCommand {
  final String command;
  final String description;

  const SlashCommand({required this.command, required this.description});

  factory SlashCommand.fromJson(Map<String, dynamic> json) {
    return SlashCommand(
      command: json['command'] ?? '',
      description: json['description'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SlashCommand && other.command == command && other.description == description;
  }

  @override
  int get hashCode => Object.hash(command, description);
}
