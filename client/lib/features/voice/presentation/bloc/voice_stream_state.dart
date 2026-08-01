import 'package:equatable/equatable.dart';

enum VoiceSessionStatus {
  inactive,
  connecting,
  listening,
  speaking,
  error,
}

class VoiceStreamState extends Equatable {
  final bool isSessionActive;
  final VoiceSessionStatus status;
  final String? errorMessage;
  final String? activeAgentId;
  final String? activeSessionId;
  final bool isMuted;

  const VoiceStreamState({
    this.isSessionActive = false,
    this.status = VoiceSessionStatus.inactive,
    this.errorMessage,
    this.activeAgentId,
    this.activeSessionId,
    this.isMuted = false,
  });

  VoiceStreamState copyWith({
    bool? isSessionActive,
    VoiceSessionStatus? status,
    String? errorMessage,
    String? activeAgentId,
    String? activeSessionId,
    bool? isMuted,
    bool clearError = false,
  }) {
    return VoiceStreamState(
      isSessionActive: isSessionActive ?? this.isSessionActive,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeAgentId: activeAgentId ?? this.activeAgentId,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  List<Object?> get props => [
    isSessionActive,
    status,
    errorMessage,
    activeAgentId,
    activeSessionId,
    isMuted,
  ];
}
