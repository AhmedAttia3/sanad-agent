import 'package:html/parser.dart' show parse;
import 'package:html2md/html2md.dart' as html2md;
import 'package:http/http.dart' as http;
import 'url_safety_validator.dart';

class WebFetchOutput {
  final int bytes;
  final int code;
  final String codeText;
  final String result;
  final int durationMs;
  final String url;

  WebFetchOutput({
    required this.bytes,
    required this.code,
    required this.codeText,
    required this.result,
    required this.durationMs,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
    'bytes': bytes,
    'code': code,
    'codeText': codeText,
    'result': result,
    'durationMs': durationMs,
    'url': url,
  };
}

class WebFetchService {
  final http.Client _client;

  static const _maxContentChars = 3000;
  static const _timeout = Duration(seconds: 20);
  static const _noiseTags = {
    'script',
    'style',
    'noscript',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'button',
    'iframe',
    'svg',
    'figure',
    'figcaption',
    'menu',
    'dialog',
    'template',
  };

  WebFetchService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<WebFetchOutput>> fetch(
    List<String> urls, {
    String prompt = '',
  }) async {
    final targetUrls = urls.take(5).toList();
    if (targetUrls.isEmpty) {
      return [];
    }
    final futures = targetUrls.map((url) => _fetchSingle(url, prompt: prompt));
    return Future.wait(futures);
  }

  Future<WebFetchOutput> _fetchSingle(String url, {String prompt = ''}) async {
    final started = DateTime.now();
    final normalizedUrl = _normalizeUrl(url);

    // SSRF Protection: Block private network requests
    if (!await UrlSafetyValidator.isSafeUrl(normalizedUrl)) {
      return WebFetchOutput(
        bytes: 0,
        code: 403,
        codeText: 'Forbidden',
        result:
            'Access to URL $url is blocked (unsafe/private address resolved).',
        durationMs: DateTime.now().difference(started).inMilliseconds,
        url: normalizedUrl,
      );
    }

    try {
      final response = await _client
          .get(
            Uri.parse(normalizedUrl),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/124.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
            },
          )
          .timeout(_timeout);

      final finalUrl = response.request?.url.toString() ?? normalizedUrl;
      final result = _buildResult(
        url: finalUrl,
        prompt: prompt,
        body: response.body,
        contentType: response.headers['content-type'] ?? '',
        statusCode: response.statusCode,
      );

      return WebFetchOutput(
        bytes: response.body.length,
        code: response.statusCode,
        codeText: response.reasonPhrase ?? 'Unknown',
        result: result,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        url: finalUrl,
      );
    } catch (error) {
      return WebFetchOutput(
        bytes: 0,
        code: 500,
        codeText: 'Error',
        result: 'Failed to fetch $url: $error',
        durationMs: DateTime.now().difference(started).inMilliseconds,
        url: normalizedUrl,
      );
    }
  }

  String _buildResult({
    required String url,
    required String prompt,
    required String body,
    required String contentType,
    required int statusCode,
  }) {
    if (statusCode < 200 || statusCode >= 300) {
      return 'HTTP $statusCode fetching $url.';
    }

    if (!contentType.contains('html')) {
      return 'Fetched $url\n\n${_truncate(body.trim(), _maxContentChars)}';
    }

    final title = _extractTitle(body);
    final content = _extractCleanText(body);
    final buffer = StringBuffer();
    buffer.writeln('URL: $url');
    if (title != null && title.isNotEmpty) {
      buffer.writeln('Title: $title');
    }
    buffer.writeln();

    if (content.isEmpty) {
      buffer.write('(No readable text content found on this page.)');
      return buffer.toString();
    }

    if (prompt.isNotEmpty) {
      buffer.writeln('Prompt: $prompt');
      buffer.writeln();
    }

    buffer.write(content);
    return buffer.toString().trimRight();
  }

  String _extractCleanText(String html) {
    final markdown = html2md.convert(
      html,
      ignore: _noiseTags.toList(),
      styleOptions: {'headingStyle': 'atx', 'codeBlockStyle': 'fenced'},
    );
    return _truncate(markdown, _maxContentChars);
  }

  String? _extractTitle(String html) {
    final document = parse(html);
    final titleElement = document.querySelector('title');
    return titleElement != null ? _collapseSpaces(titleElement.text) : null;
  }

  String _collapseSpaces(String value) =>
      value.trim().replaceAll(RegExp(r'[ \t]+'), ' ');

  String _truncate(String value, int max) {
    return value.length <= max
        ? value
        : '${value.substring(0, max).trimRight()}…';
  }

  String _normalizeUrl(String url) {
    var uri = Uri.parse(url);
    if (uri.scheme == 'http') {
      final host = uri.host;
      if (host != 'localhost' && host != '127.0.0.1' && host != '::1') {
        uri = uri.replace(scheme: 'https');
      }
    }
    return uri.toString();
  }
}
