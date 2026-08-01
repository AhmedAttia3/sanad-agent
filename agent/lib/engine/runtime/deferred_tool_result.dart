import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class DeferredToolResultDescriptor {
  const DeferredToolResultDescriptor({
    required this.kind,
    required this.transactionId,
    required this.manifestPath,
    required this.requesterSessionId,
    required this.requesterToolCallId,
    this.timeoutSeconds = 300,
  });

  static const envelopeKey = 'sanad_deferred_tool_result';
  static const supportedKind = 'sanad_dev_switch';

  final String kind;
  final String transactionId;
  final String manifestPath;
  final String requesterSessionId;
  final String requesterToolCallId;
  final int timeoutSeconds;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'transaction_id': transactionId,
    'manifest_path': manifestPath,
    'requester_session_id': requesterSessionId,
    'requester_tool_call_id': requesterToolCallId,
    'timeout_seconds': timeoutSeconds,
  };

  static DeferredToolResultDescriptor? tryParseToolResult(
    String raw, {
    required String sessionId,
    required String toolCallId,
  }) {
    try {
      Object? decoded = jsonDecode(raw);
      if (decoded is Map && decoded['output'] is String) {
        decoded = jsonDecode((decoded['output'] as String).trim());
      }
      if (decoded is! Map || decoded[envelopeKey] is! Map) return null;
      final value = Map<String, dynamic>.from(decoded[envelopeKey] as Map);
      final descriptor = DeferredToolResultDescriptor(
        kind: _requiredString(value, 'kind'),
        transactionId: _requiredString(value, 'transaction_id'),
        manifestPath: _requiredString(value, 'manifest_path'),
        requesterSessionId: _requiredString(value, 'requester_session_id'),
        requesterToolCallId: _requiredString(value, 'requester_tool_call_id'),
        timeoutSeconds: _optionalInt(value['timeout_seconds']) ?? 300,
      );
      if (descriptor.kind != supportedKind ||
          descriptor.requesterSessionId != sessionId ||
          descriptor.requesterToolCallId != toolCallId ||
          descriptor.timeoutSeconds < 1 ||
          descriptor.timeoutSeconds > 900) {
        return null;
      }
      return descriptor;
    } on Object {
      return null;
    }
  }

  static DeferredToolResultDescriptor? tryParseMetadata(Object? raw) {
    if (raw is! Map) return null;
    try {
      final value = Map<String, dynamic>.from(raw);
      final descriptor = DeferredToolResultDescriptor(
        kind: _requiredString(value, 'kind'),
        transactionId: _requiredString(value, 'transaction_id'),
        manifestPath: _requiredString(value, 'manifest_path'),
        requesterSessionId: _requiredString(value, 'requester_session_id'),
        requesterToolCallId: _requiredString(value, 'requester_tool_call_id'),
        timeoutSeconds: _optionalInt(value['timeout_seconds']) ?? 300,
      );
      return descriptor.kind == supportedKind ? descriptor : null;
    } on Object {
      return null;
    }
  }

  static String _requiredString(Map<String, dynamic> value, String key) {
    final result = value[key]?.toString().trim();
    if (result == null || result.isEmpty) {
      throw FormatException('Missing deferred result field: $key');
    }
    return result;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class DeferredToolResultResolution {
  const DeferredToolResultResolution({
    required this.output,
    required this.isError,
  });

  final String output;
  final bool isError;
}

class DeferredToolResultResolver {
  const DeferredToolResultResolver({
    this.pollInterval = const Duration(milliseconds: 250),
    this.readManifest,
    this.environment,
  });

  final Duration pollInterval;
  final Future<String> Function(String path)? readManifest;
  final Map<String, String>? environment;

  Future<DeferredToolResultResolution> resolve(
    DeferredToolResultDescriptor descriptor,
  ) async {
    try {
      _validateManifestPath(descriptor.manifestPath);
    } on FormatException catch (error) {
      return DeferredToolResultResolution(
        output: 'Error: ${error.message}',
        isError: true,
      );
    }
    final deadline = DateTime.now().add(
      Duration(seconds: descriptor.timeoutSeconds),
    );
    while (true) {
      try {
        final raw =
            await (readManifest?.call(descriptor.manifestPath) ??
                File(descriptor.manifestPath).readAsString());
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final manifest = Map<String, dynamic>.from(decoded);
          _validateIdentity(descriptor, manifest);
          final status = manifest['status']?.toString();
          if (_terminalStatuses.contains(status)) {
            return _renderTerminal(status!, manifest);
          }
        }
      } on StateError catch (error) {
        return DeferredToolResultResolution(
          output: 'Error: ${error.message}',
          isError: true,
        );
      } on FileSystemException {
        // The launcher may be atomically replacing the manifest.
      } on FormatException {
        // An incomplete/invalid record is retried until the bounded deadline.
      }
      if (DateTime.now().isAfter(deadline)) {
        return const DeferredToolResultResolution(
          output:
              'Error: Runtime source switch result timed out before a terminal launcher outcome was recorded.',
          isError: true,
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  static const _terminalStatuses = {
    'complete',
    'rolled_back',
    'failed',
    'recovery_failed',
  };

  void _validateManifestPath(String manifestPath) {
    final env = environment ?? Platform.environment;
    final sanadHome = env['SANAD_HOME']?.trim();
    if (sanadHome == null || sanadHome.isEmpty) {
      throw const FormatException(
        'SANAD_HOME is required to resolve a deferred switch result.',
      );
    }
    final allowedRoot = p.normalize(p.absolute(p.join(sanadHome, 'dev')));
    final candidate = p.normalize(p.absolute(manifestPath));
    if (candidate != allowedRoot && !p.isWithin(allowedRoot, candidate)) {
      throw const FormatException(
        'Deferred switch manifest is outside the active Sanad Home.',
      );
    }
  }

  void _validateIdentity(
    DeferredToolResultDescriptor descriptor,
    Map<String, dynamic> manifest,
  ) {
    if (manifest['id']?.toString() != descriptor.transactionId ||
        manifest['requester_session_id']?.toString() !=
            descriptor.requesterSessionId ||
        manifest['requester_tool_call_id']?.toString() !=
            descriptor.requesterToolCallId) {
      throw StateError(
        'Deferred switch manifest identity does not match the requester.',
      );
    }
  }

  DeferredToolResultResolution _renderTerminal(
    String status,
    Map<String, dynamic> manifest,
  ) {
    final target =
        manifest['target_worktree_name']?.toString() ?? 'requested target';
    final message = manifest['message']?.toString().trim();
    final detail = message == null || message.isEmpty
        ? ''
        : ' Reason: $message';
    return switch (status) {
      'complete' => DeferredToolResultResolution(
        output:
            'Switch complete: runtime moved to $target. The original session resumed on the target runtime.$detail',
        isError: false,
      ),
      'rolled_back' => DeferredToolResultResolution(
        output:
            'Switch rolled back: target startup failed. The previous source runtime was restored and the original session resumed successfully.$detail',
        isError: false,
      ),
      'recovery_failed' => DeferredToolResultResolution(
        output:
            'Error: Runtime source switch failed and the previous source runtime could not be restored.$detail',
        isError: true,
      ),
      _ => DeferredToolResultResolution(
        output: 'Error: Runtime source switch failed before completion.$detail',
        isError: true,
      ),
    };
  }
}
