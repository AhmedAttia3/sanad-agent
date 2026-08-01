enum TurnReplayAction { retry, edit }

enum TurnReplaySafety { safe, unsafe, unknown }

class TurnReplayResult {
  final String outcome;
  final TurnReplaySafety safety;
  final bool requiresConfirmation;

  const TurnReplayResult({
    required this.outcome,
    required this.safety,
    required this.requiresConfirmation,
  });

  bool get isAccepted => outcome == 'accepted';

  factory TurnReplayResult.fromJson(Map<String, dynamic> json) {
    final safetyName = json['replay_safety']?.toString();
    return TurnReplayResult(
      outcome: json['outcome']?.toString() ?? 'invalid_response',
      safety: TurnReplaySafety.values.firstWhere(
        (value) => value.name == safetyName,
        orElse: () => TurnReplaySafety.unknown,
      ),
      requiresConfirmation: json['requires_confirmation'] == true,
    );
  }
}
