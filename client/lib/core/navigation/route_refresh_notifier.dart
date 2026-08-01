import 'dart:async';
import 'package:flutter/foundation.dart';

class RouteRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  StreamSubscription<dynamic>? _subscription2;

  RouteRefreshNotifier(Stream<dynamic> stream, [Stream<dynamic>? stream2]) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
    if (stream2 != null) {
      _subscription2 = stream2.asBroadcastStream().listen(
        (dynamic _) => notifyListeners(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_subscription2?.cancel());
    super.dispose();
  }
}
