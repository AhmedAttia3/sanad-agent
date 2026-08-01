class SearchHit {
  final String title;
  final String url;
  final String snippet;

  const SearchHit({required this.title, required this.url, this.snippet = ''});

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
  };
}

class WebSearchResult {
  final List<SearchHit> hits;
  final String? directAnswer;

  const WebSearchResult({required this.hits, this.directAnswer});
}

abstract class WebSearchProvider {
  String get name;

  /// Whether the provider is configured (e.g. has API keys, or is enabled).
  bool get isConfigured;

  /// Performs a search for [query] and returns a [WebSearchResult].
  ///
  /// Optional [allowedDomains] can be provided to restrict the search.
  /// Optional [limit] controls the maximum number of results (defaults to 6).
  Future<WebSearchResult> search(
    String query, {
    List<String>? allowedDomains,
    int? limit,
  });
}
