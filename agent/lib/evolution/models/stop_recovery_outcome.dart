class StopRecoveryItem {
  final String requestId;
  final String source;
  final String text;
  final DateTime receivedAt;

  const StopRecoveryItem({
    required this.requestId,
    required this.source,
    required this.text,
    required this.receivedAt,
  });

  factory StopRecoveryItem.fromJson(Map<String, dynamic> json) {
    return StopRecoveryItem(
      requestId: json['request_id'] as String,
      source: json['source'] as String,
      text: json['text'] as String,
      receivedAt: DateTime.parse(json['received_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'source': source,
    'text': text,
    'received_at': receivedAt.toIso8601String(),
  };
}

class StopRecoveryOutcome {
  final String sessionId;
  final String stopRequestId;
  final List<StopRecoveryItem> items;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final String recoveryReason;
  final bool claimRequired;
  final String? claimedBy;

  const StopRecoveryOutcome({
    required this.sessionId,
    required this.stopRequestId,
    required this.items,
    required this.createdAt,
    this.acknowledgedAt,
    this.recoveryReason = 'user_stop',
    this.claimRequired = false,
    this.claimedBy,
  });

  bool get isAcknowledged => acknowledgedAt != null;

  Map<String, dynamic> toPayload() => {
    'session_id': sessionId,
    'stop_request_id': stopRequestId,
    'items': claimRequired
        ? const <Map<String, dynamic>>[]
        : items.map((item) => item.toJson()).toList(),
    if (claimRequired) 'item_count': items.length,
    'created_at': createdAt.toIso8601String(),
    'acknowledged': isAcknowledged,
    'recovery_reason': recoveryReason,
    'claim_required': claimRequired,
    if (recoveryReason == 'daemon_restart' &&
        !claimRequired &&
        claimedBy != null)
      'claimed_by': claimedBy,
  };
}
