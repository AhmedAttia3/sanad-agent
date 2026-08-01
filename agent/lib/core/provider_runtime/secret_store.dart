import 'secret_record.dart';

/// Abstract contract for instance-keyed credential storage (Plan 29 §7.4).
///
/// Keys are `ProviderInstance` UUIDs — never template ids — so multiple
/// accounts of the same provider never overwrite each other. The raw
/// [SecretRecord] is read only by the runtime resolver; callers that need to
/// render a card MUST use [summary], which masks every secret.
///
/// The first implementation is [`SecureFileSecretStore`]
///(secure_file_secret_store.dart) (atomic, locked, owner-only). The
/// abstraction allows an OS keychain backend later without touching callers.
abstract class SecretStore {
  /// Returns the raw record for [instanceId], or null when none is stored.
  /// Caller MUST NOT forward the result to clients/CLI/logs.
  SecretRecord? read(String instanceId);

  /// Persists (or atomically replaces) the record for its instance. Other
  /// instances are never touched by this call.
  Future<void> write(String instanceId, SecretRecord record);

  /// Returns a secret-free summary safe to send to clients/CLI.
  SecretSummary summary(String instanceId);

  /// Removes only the record for [instanceId]. Other instances are untouched.
  Future<void> remove(String instanceId);

  /// Lists every instance id that has a stored secret.
  List<String> listIds();

  /// Atomically removes records whose ids are absent from [validInstanceIds].
  /// Used by credential mutations to reconcile secrets with authoritative
  /// provider-instance metadata after interrupted or legacy deletion flows.
  Future<void> pruneOrphans(Set<String> validInstanceIds);
}
