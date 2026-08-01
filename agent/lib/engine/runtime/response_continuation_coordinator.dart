/// Turn-scoped budgets for semantic continuation and provider-state fallback.
///
/// These counters are intentionally independent from transport retry budgets.
class ResponseContinuationCoordinator {
  static const maxIncompleteContinuations = 3;

  int _incompleteContinuations = 0;
  bool _providerStateFallbackUsed = false;

  int get incompleteContinuations => _incompleteContinuations;

  bool claimIncompleteContinuation() {
    if (_incompleteContinuations >= maxIncompleteContinuations) return false;
    _incompleteContinuations += 1;
    return true;
  }

  bool claimProviderStateFallback() {
    if (_providerStateFallbackUsed) return false;
    _providerStateFallbackUsed = true;
    return true;
  }
}
