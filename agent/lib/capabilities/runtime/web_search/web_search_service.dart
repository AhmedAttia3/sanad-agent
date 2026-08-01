import 'package:http/http.dart' as http;
import 'web_search_provider.dart';
import 'serper_provider.dart';
import 'duckduckgo_provider.dart';
import 'url_safety_validator.dart';

// Re-export SearchHit for backward compatibility with other catalog classes
export 'web_search_provider.dart' show SearchHit, WebSearchResult;

class WebSearchService {
  static const int _defaultResultLimit = 6;
  static const int _maxResultLimit = 10;

  final http.Client _client;
  final List<WebSearchProvider>? _fixedProviders;
  final String Function() _preferredProvider;
  final String Function() _serperApiKey;

  WebSearchService({
    http.Client? client,
    String? serperApiKey,
    List<WebSearchProvider>? providers,
    String? preferredProvider,
    String Function()? preferredProviderResolver,
    String Function()? serperApiKeyResolver,
  }) : _client = client ?? http.Client(),
       _fixedProviders = providers,
       _preferredProvider =
           preferredProviderResolver ??
           (() => preferredProvider?.trim().toLowerCase() ?? ''),
       _serperApiKey = serperApiKeyResolver ?? (() => serperApiKey ?? '');

  /// Performs a search across configured providers with fallback logic.
  ///
  /// Safe results are returned as a markdown formatted string.
  /// Optional [allowedDomains] limits results to specific hosts.
  /// Optional [limit] sets maximum search results to return.
  Future<String> search(
    String query, {
    List<String>? allowedDomains,
    int? limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('query is required');
    }

    final effectiveLimit = (limit ?? _defaultResultLimit).clamp(
      1,
      _maxResultLimit,
    );

    // Resolve configuration for every tool call so persisted changes apply to
    // an already-running daemon without rebuilding the service.
    final preferredProvider = _preferredProvider().trim().toLowerCase();
    final orderedProviders = List<WebSearchProvider>.from(
      _fixedProviders ??
          [
            SerperProvider(client: _client, apiKey: _serperApiKey()),
            DuckDuckGoProvider(client: _client),
          ],
    );
    if (preferredProvider.isNotEmpty) {
      orderedProviders.sort((a, b) {
        if (a.name == preferredProvider) return -1;
        if (b.name == preferredProvider) return 1;
        return 0;
      });
    }

    for (final provider in orderedProviders) {
      if (!provider.isConfigured) {
        continue;
      }

      try {
        final result = await provider.search(
          trimmed,
          allowedDomains: allowedDomains,
          limit: effectiveLimit,
        );

        if (result.hits.isNotEmpty) {
          // SSRF Protection: Filter out any unsafe/private URLs
          final safeHits = <SearchHit>[];
          for (final hit in result.hits) {
            if (await UrlSafetyValidator.isSafeUrl(hit.url)) {
              safeHits.add(hit);
            }
          }

          if (safeHits.isNotEmpty) {
            return _formatOutput(
              trimmed,
              safeHits,
              directAnswer: result.directAnswer,
            );
          }
        }
      } catch (_) {
        // Log or handle provider failure internally, proceed to next fallback
        continue;
      }
    }

    return _noResults(trimmed);
  }

  String _formatOutput(
    String query,
    List<SearchHit> hits, {
    String? directAnswer,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Search results for: "$query"');

    if (directAnswer != null && directAnswer.isNotEmpty) {
      buffer.writeln('\nDirect answer: $directAnswer');
    }

    buffer.writeln();
    for (final hit in hits) {
      buffer.writeln('**${hit.title}**');
      if (hit.snippet.isNotEmpty) {
        buffer.writeln(hit.snippet);
      }
      buffer.writeln(hit.url);
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  String _noResults(String query) =>
      'No web search results found for "$query".';
}
