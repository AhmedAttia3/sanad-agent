class DeviceProcessingSnapshot {
  final bool isDraftProcessing;
  final Set<String> sessionIds;

  const DeviceProcessingSnapshot({
    this.isDraftProcessing = false,
    this.sessionIds = const {},
  });

  bool get isProcessing => isDraftProcessing || sessionIds.isNotEmpty;

  bool isSessionProcessing(String? sessionId) => sessionId != null && sessionIds.contains(sessionId);
}
