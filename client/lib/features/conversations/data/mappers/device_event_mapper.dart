import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';

/// Base interface for mapping raw agent events to CanonicalEvent
abstract class DeviceEventMapper {
  /// Maps a live event from the stream to a CanonicalEvent
  CanonicalEvent? mapLiveEvent(Map<String, dynamic> event);

  /// Maps a list of events from history to a list of CanonicalEvents
  List<CanonicalEvent> mapHistory(List<dynamic> history);
}
