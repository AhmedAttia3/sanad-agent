import 'package:equatable/equatable.dart';

/// Monotonic token used to reject stale daemon responses.
///
/// The store advances the generation whenever a new refresh or device switch
/// supersedes in-flight requests. A response carrying an older generation must
/// not overwrite a newer snapshot (Plan 32 §"دمج البيانات والأحداث": "response
/// قديمة تحمل request generation غير الحالية لا تستبدل نتيجة أحدث").
class RequestGeneration extends Equatable implements Comparable<RequestGeneration> {
  final int value;

  const RequestGeneration(this.value);

  /// Initial generation for a freshly created store.
  static const RequestGeneration initial = RequestGeneration(0);

  RequestGeneration next() => RequestGeneration(value + 1);

  /// True if this generation is strictly newer than [other].
  bool isAfter(RequestGeneration other) => value > other.value;

  @override
  int compareTo(RequestGeneration other) => value.compareTo(other.value);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => 'RequestGeneration($value)';
}
