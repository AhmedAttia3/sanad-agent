import '../models/delivery/models.dart';
import '../models/gateway_event.dart';

/// Base class for all platform adapters (CLI, Webhook, WebSocket, etc.)
abstract class BasePlatform {
  String get platformId;

  /// Phase 27 — typed, extensible platform topology descriptor.
  ///
  /// Adapters declare their family/transport/instance here. `GatewayManager`
  /// routes by family without a switch over platform names. Two adapters
  /// sharing `PlatformFamily.sanadClient` (local + cloud) synchronize live
  /// Sanad events; external families (`telegram`/`whatsapp`/`cli`) are
  /// isolated to their own origin route.
  PlatformDescriptor get descriptor;

  /// Platforms with this flag receive mirrored responses from other origins.
  ///
  /// Phase 27 NOTE: this flag is retained only as a transport capability
  /// indicator while the new delivery-policy routing is wired up. The
  /// per-event `GatewayResponse.delivery` is the authoritative routing
  /// decision; see `GatewayManager` phase C.
  bool get receivesMirroredResponses => false;

  /// Platforms with this flag receive a synthesized user-message echo
  /// before the assistant stream begins.
  bool get shouldReceiveUserEcho => false;

  /// Stream of events coming from this platform.
  Stream<GatewayEvent> get eventStream;

  /// Send a response back to the platform.
  Future<void> sendResponse(GatewayResponse response);

  /// Initialize the platform.
  Future<void> initialize();

  /// Dispose/Shutdown the platform.
  Future<void> dispose();
}
