import 'package:path/path.dart' as p;

import '../constants.dart';
import 'provider_instance.dart';
import 'provider_instance_repository.dart';
import 'provider_protocol_constants.dart';
import 'secret_record.dart';
import 'secret_store.dart';
import 'secure_file_secret_store.dart';

/// Owns credential edits for `ProviderInstance` rows (Plan 29 §7.5, §8.1).
///
/// The single entry point for `keep` | `replace` | `remove` credential actions:
/// - `keep` (default) never touches the stored secret or the revision.
/// - `replace` writes the new secret into the `SecretStore` (keyed by instance
///   UUID) and bumps `credentialRevision` so adapters/caches bound to the old
///   credential are invalidated.
/// - `remove` deletes the secret and bumps the revision.
/// `replace` without a value is rejected. An empty field never means `remove`.
///
/// Only the masked [`SecretSummary`] ever leaves this service — raw
/// [`SecretRecord`] access is reserved for the runtime resolver.
class ProviderCredentialService {
  final ProviderInstanceRepository _repo;
  final SecretStore _secrets;

  ProviderCredentialService(this._repo, this._secrets);

  // ── Read ─────────────────────────────────────────────────────────────

  /// Returns a secret-free summary safe to send to clients/CLI.
  SecretSummary summary(String instanceId) => _secrets.summary(instanceId);

  /// Returns summaries for all instances (used by `provider.instances.list`).
  List<SecretSummary> summaries(Iterable<String> instanceIds) {
    return instanceIds
        .map((id) => _secrets.summary(id))
        .toList(growable: false);
  }

  /// Returns the raw record. MUST only be called by the runtime resolver; the
  /// result MUST NOT be forwarded to clients, CLI, logs, or DTOs.
  SecretRecord? rawForResolver(String instanceId) => _secrets.read(instanceId);

  // ── API key: keep / replace / remove ──────────────────────────────────

  /// Applies a credential edit action for an API-key instance. Returns the
  /// updated masked summary.
  ///
  /// - [action] = `keep` (default): no store change, no revision bump.
  /// - [action] = `replace`: [newApiKey] MUST be non-empty; writes it and
  ///   bumps `credentialRevision`.
  /// - [action] = `remove`: deletes the secret and bumps `credentialRevision`.
  ///
  /// An empty [newApiKey] when `action=replace` is rejected. `null`/empty
  /// never means `remove`. Other live instances are never touched; credential
  /// mutations may prune stored UUIDs that have no authoritative instance when
  /// state and secrets share one Sanad Home boundary.

  Future<SecretSummary> applyApiKeyEdit(
    String instanceId, {
    String action = CredentialAction.keep,
    String? newApiKey,
    DateTime? now,
  }) async {
    final existing = _repo.findById(instanceId);
    if (existing == null) {
      throw StateError('Provider instance not found: $instanceId');
    }
    switch (action) {
      case CredentialAction.keep:
        // No store change, no revision bump.
        break;
      case CredentialAction.replace:
        final key = newApiKey?.trim() ?? '';
        if (key.isEmpty) {
          throw ArgumentError('replace requires a non-empty API key.');
        }
        await _pruneOrphanedSecrets();
        await _secrets.write(
          instanceId,
          SecureFileSecretStore.apiKeyRecord(instanceId, key),
        );
        _bumpCredentialRevision(existing, now);
        break;
      case CredentialAction.remove:
        await _pruneOrphanedSecrets();
        await _secrets.remove(instanceId);
        _bumpCredentialRevision(existing, now);
        break;
      default:
        throw ArgumentError('Unknown credential action: $action');
    }
    return _secrets.summary(instanceId);
  }

  // ── OAuth: reconnect / disconnect ────────────────────────────────────

  /// Persists an OAuth token bundle obtained by `ProviderAuthSessionService`.
  /// Bumps `credentialRevision`. Used after a successful auth flow or refresh.
  Future<void> writeOAuthBundle(
    String instanceId,
    SecretRecord record, {
    DateTime? now,
  }) async {
    final existing = _repo.findById(instanceId);
    if (existing == null) {
      throw StateError('Provider instance not found: $instanceId');
    }
    await _pruneOrphanedSecrets();
    await _secrets.write(instanceId, record);
    _bumpCredentialRevision(existing, now);
  }

  /// Disconnects an OAuth instance: deletes the tokens and bumps the
  /// revision. The instance is NOT deleted — its metadata stays so the user
  /// can reconnect later (Plan 29 §6.2).
  Future<void> disconnect(String instanceId, {DateTime? now}) async {
    final existing = _repo.findById(instanceId);
    if (existing == null) {
      throw StateError('Provider instance not found: $instanceId');
    }
    await _pruneOrphanedSecrets();
    await _secrets.remove(instanceId);
    _bumpCredentialRevision(existing, now);
  }

  // ── Cascade: delete secret when the instance is removed ───────────────

  /// Removes this instance's secret and reconciles unrelated orphan records.
  /// Credentials belonging to other live instances remain untouched.
  Future<void> deleteSecret(String instanceId) async {
    await _pruneOrphanedSecrets();
    await _secrets.remove(instanceId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Future<void> _pruneOrphanedSecrets() {
    // An explicit state-home override can share one SANAD_HOME secret store
    // with another state database. Never infer orphans across that boundary.
    if (!p.equals(getSanadStateHome(), getSanadHome())) {
      return Future.value();
    }
    final validInstanceIds = _repo
        .findAll()
        .map((instance) => instance.id)
        .toSet();
    return _secrets.pruneOrphans(validInstanceIds);
  }

  void _bumpCredentialRevision(ProviderInstance instance, DateTime? now) {
    _repo.update(
      instance.copyWith(
        credentialRevision: instance.credentialRevision + 1,
        updatedAt: now ?? DateTime.now(),
      ),
    );
  }
}
