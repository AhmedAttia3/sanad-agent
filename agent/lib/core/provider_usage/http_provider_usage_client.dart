/// Production [ProviderUsageHttpClient] backed by `package:http`.
///
/// Each fetch owns a fresh `http.Client`; the adapter closes it when done.
/// Keeping this thin and isolated means adapters depend only on the abstract
/// surface and tests inject a fake without touching the network.
library;

import 'package:http/http.dart' as http;

import 'provider_usage_adapter.dart';

class HttpProviderUsageHttpClient implements ProviderUsageHttpClient {
  final http.Client _client = http.Client();

  @override
  Future<ProviderUsageHttpResponse> get(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final request = _client.get(url, headers: headers ?? const {});
    final resp = timeout == null
        ? await request
        : await request.timeout(timeout);
    return ProviderUsageHttpResponse(resp.statusCode, resp.body);
  }

  @override
  Future<ProviderUsageHttpResponse> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final request = _client.post(url, headers: headers ?? const {}, body: body);
    final resp = timeout == null
        ? await request
        : await request.timeout(timeout);
    return ProviderUsageHttpResponse(resp.statusCode, resp.body);
  }

  @override
  void close() => _client.close();
}

/// Default factory used in production DI.
ProviderUsageHttpClient defaultHttpClientFactory() =>
    HttpProviderUsageHttpClient();
