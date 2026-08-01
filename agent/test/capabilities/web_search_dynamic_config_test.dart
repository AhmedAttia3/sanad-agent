import 'package:sanad_agent/capabilities/runtime/web_search/web_search_provider.dart';
import 'package:sanad_agent/capabilities/runtime/web_search/web_search_service.dart';
import 'package:test/test.dart';

class _RecordingProvider implements WebSearchProvider {
  _RecordingProvider(this.name, this.calls);

  @override
  final String name;
  final List<String> calls;

  @override
  bool get isConfigured => true;

  @override
  Future<WebSearchResult> search(
    String query, {
    List<String>? allowedDomains,
    int? limit,
  }) async {
    calls.add(name);
    throw StateError('Continue to fallback');
  }
}

void main() {
  test('resolves the preferred provider for every search call', () async {
    final calls = <String>[];
    var preferred = 'ddg';
    final service = WebSearchService(
      providers: [
        _RecordingProvider('serper', calls),
        _RecordingProvider('ddg', calls),
      ],
      preferredProviderResolver: () => preferred,
    );

    await service.search('first');
    expect(calls, ['ddg', 'serper']);

    calls.clear();
    preferred = 'serper';
    await service.search('second');
    expect(calls, ['serper', 'ddg']);
  });
}
