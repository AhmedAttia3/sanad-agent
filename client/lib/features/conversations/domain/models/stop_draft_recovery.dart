import 'package:equatable/equatable.dart';

class RecoveredInput extends Equatable {
  final String requestId;
  final String source;
  final String text;
  final DateTime? receivedAt;

  const RecoveredInput({required this.requestId, required this.source, required this.text, required this.receivedAt});

  factory RecoveredInput.fromJson(Map<String, dynamic> json) => RecoveredInput(
    requestId: json['request_id']?.toString() ?? '',
    source: json['source']?.toString() ?? '',
    text: json['text']?.toString() ?? '',
    receivedAt: DateTime.tryParse(json['received_at']?.toString() ?? ''),
  );

  @override
  List<Object?> get props => [requestId, source, text, receivedAt];
}

class StopDraftRecovery extends Equatable {
  final String sessionId;
  final String stopRequestId;
  final List<RecoveredInput> inputs;
  final String recoveryReason;
  final bool claimRequired;
  final String? claimedBy;

  const StopDraftRecovery({
    required this.sessionId,
    required this.stopRequestId,
    required this.inputs,
    this.recoveryReason = 'user_stop',
    this.claimRequired = false,
    this.claimedBy,
  });

  factory StopDraftRecovery.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id']?.toString() ?? '';
    final stopRequestId = json['stop_request_id']?.toString() ?? '';
    if (sessionId.isEmpty || stopRequestId.isEmpty) {
      throw const FormatException('Stop recovery requires session_id and stop_request_id.');
    }
    return StopDraftRecovery(
      sessionId: sessionId,
      stopRequestId: stopRequestId,
      recoveryReason: json['recovery_reason']?.toString() ?? 'user_stop',
      claimRequired: json['claim_required'] == true,
      claimedBy: json['claimed_by']?.toString(),
      inputs: (json['inputs'] as List? ?? json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => RecoveredInput.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    stopRequestId,
    inputs,
    recoveryReason,
    claimRequired,
    claimedBy,
  ];
}
