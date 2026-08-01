import 'dart:convert';
import 'package:http/http.dart' as http;
import 'web_search_provider.dart';

class SerperProvider implements WebSearchProvider {
  final http.Client _client;
  final String? _apiKey;

  @override
  String get name => 'serper';

  @override
  bool get isConfigured => _apiKey != null && _apiKey.isNotEmpty;

  SerperProvider({required http.Client client, String? apiKey})
    : _client = client,
      _apiKey = apiKey;

  @override
  Future<WebSearchResult> search(
    String query, {
    List<String>? allowedDomains,
    int? limit,
  }) async {
    if (!isConfigured) {
      throw StateError('Serper API key is not configured');
    }

    final maxResults = limit ?? 6;
    var finalQuery = query.trim();

    // Apply allowedDomains filter via Google search query syntax
    if (allowedDomains != null && allowedDomains.isNotEmpty) {
      final domainFilter = allowedDomains.map((d) => 'site:$d').join(' OR ');
      finalQuery = '$finalQuery ($domainFilter)';
    }

    final response = await _client.post(
      Uri.https('google.serper.dev', '/search'),
      headers: {'X-API-KEY': _apiKey!, 'Content-Type': 'application/json'},
      body: jsonEncode({'q': finalQuery, 'num': maxResults}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Serper API returned status code ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final organic = json['organic'];
    if (organic is! List) {
      return const WebSearchResult(hits: []);
    }

    final hits = organic
        .whereType<Map>()
        .take(maxResults)
        .map(
          (item) => SearchHit(
            title: item['title']?.toString() ?? '',
            url: item['link']?.toString() ?? '',
            snippet: item['snippet']?.toString() ?? '',
          ),
        )
        .where((hit) => hit.url.startsWith('http') && hit.title.isNotEmpty)
        .toList();

    final answerBox = json['answerBox'];
    String? directAnswer;
    if (answerBox is Map) {
      final ans =
          (answerBox['answer'] ?? answerBox['snippet'])?.toString() ?? '';
      if (ans.isNotEmpty) {
        directAnswer = ans.length <= 240
            ? ans
            : '${ans.substring(0, 240).trimRight()}…';
      }
    }

    return WebSearchResult(hits: hits, directAnswer: directAnswer);
  }
}
