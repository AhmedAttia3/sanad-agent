class ChatMessage {
  final int? id;
  final String sender; // 'user', 'ai', 'system'
  final String type; // 'text', 'tool_use', 'tool_result', 'thought', 'final_answer'
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ChatMessage({
    this.id,
    required this.sender,
    required this.type,
    required this.content,
    this.metadata,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      sender: json['sender'],
      type: json['type'],
      content: json['content'],
      metadata: json['metadata'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'type': type,
      'content': content,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => sender == 'user';
  bool get isAI => sender == 'ai';
  bool get isTool => type == 'tool_use' || type == 'tool_result';
}
