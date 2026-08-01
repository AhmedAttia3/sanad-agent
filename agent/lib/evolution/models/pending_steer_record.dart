enum PendingSteerState { pending, delivering, delivered, cancelled, recovered }

class PendingSteerRecord {
  final String sessionId;
  final String requestId;
  final String runId;
  final int generation;
  final String text;
  final DateTime receivedAt;
  final PendingSteerState state;
  final int revision;
  final DateTime updatedAt;

  const PendingSteerRecord({
    required this.sessionId,
    required this.requestId,
    required this.runId,
    required this.generation,
    required this.text,
    required this.receivedAt,
    required this.state,
    required this.revision,
    required this.updatedAt,
  });

  factory PendingSteerRecord.fromRow(Map<String, Object?> row) {
    return PendingSteerRecord(
      sessionId: row['session_id'] as String,
      requestId: row['request_id'] as String,
      runId: row['run_id'] as String,
      generation: row['generation'] as int,
      text: row['text'] as String,
      receivedAt: DateTime.parse(row['received_at'] as String).toUtc(),
      state: PendingSteerState.values.byName(row['state'] as String),
      revision: row['revision'] as int,
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toPayload() => {
    'session_id': sessionId,
    'request_id': requestId,
    'run_id': runId,
    'generation': generation,
    'text': text,
    'received_at': receivedAt.toIso8601String(),
    'state': state.name,
    'revision': revision,
    'updated_at': updatedAt.toIso8601String(),
  };
}

enum PendingSteerCancelOutcome {
  cancelled,
  deliveryInProgress,
  alreadyDelivered,
  alreadyCancelled,
  staleOwner,
  notFound,
}

enum PendingSteerReserveOutcome {
  reserved,
  alreadyReserved,
  alreadyDelivered,
  cancelled,
  staleOwner,
  notFound,
}

class PendingSteerMutation<T> {
  final T outcome;
  final PendingSteerRecord? record;

  const PendingSteerMutation(this.outcome, this.record);
}
