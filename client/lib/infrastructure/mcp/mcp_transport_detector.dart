import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mcp_client/mcp_client.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';

/// نتيجة اختبار الاتصال
class ConnectionTestResult {
  final bool success;
  final String message;
  final McpTransportType? detectedTransport;
  final List<String>? availableTools;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiry;
  final String? oauthClientId;
  final String? oauthTokenUrl;
  final String? oauthAuthUrl;

  ConnectionTestResult({
    required this.success,
    required this.message,
    this.detectedTransport,
    this.availableTools,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiry,
    this.oauthClientId,
    this.oauthTokenUrl,
    this.oauthAuthUrl,
  });
}

/// Result of a successful OAuth flow including metadata
class OAuthFlowResult {
  final OAuthToken token;
  final OAuthMetadata metadata;
  OAuthFlowResult({required this.token, required this.metadata});
}

/// Metadata discovered during OAuth flow
class OAuthMetadata {
  final String? clientId;
  final String? tokenEndpoint;
  final String? authEndpoint;
  OAuthMetadata({this.clientId, this.tokenEndpoint, this.authEndpoint});
}

/// كاشف بروتوكول النقل واختبار الاتصال
class McpTransportDetector {
  static final _logger = Logger('McpTransportDetector');

  /// اختبار الاتصال مع الخادم وكشف البروتوكول
  static Future<ConnectionTestResult> testConnection({
    required String serverUrl,
    required McpAuthType authType,
    String? oauthClientId,
    String? oauthClientSecret,
    Map<String, String>? headers,
  }) async {
    try {
      // If OAuth is required, perform interactive OAuth flow first
      Map<String, String>? authHeaders;
      OAuthFlowResult? oauthResult;

      if (authType == McpAuthType.oauth) {
        _logger.info('Starting OAuth flow for $serverUrl...');
        oauthResult = await _performInteractiveOAuth(serverUrl);

        if (oauthResult == null) {
          return ConnectionTestResult(
            success: false,
            message: 'OAuth authentication cancelled or failed',
          );
        }

        authHeaders = {'Authorization': 'Bearer ${oauthResult.token.accessToken}'};
        _logger.info('OAuth successful! Got access token.');
      } else if (headers != null) {
        authHeaders = headers;
      }

      // 1. Try Streamable HTTP first (most common for modern MCP servers)
      final streamableResult = await _tryStreamableHttp(
        serverUrl: serverUrl,
        authType: authType,
        headers: authHeaders,
      );

      if (streamableResult.success) {
        // Pass back the tokens if we got them
        if (oauthResult != null) {
          return ConnectionTestResult(
            success: true,
            message: streamableResult.message,
            detectedTransport: streamableResult.detectedTransport,
            availableTools: streamableResult.availableTools,
            accessToken: oauthResult.token.accessToken,
            refreshToken: oauthResult.token.refreshToken,
            tokenExpiry: oauthResult.token.expiresIn != null
                ? DateTime.now().add(Duration(seconds: oauthResult.token.expiresIn!))
                : null,
            oauthClientId: oauthResult.metadata.clientId,
            oauthTokenUrl: oauthResult.metadata.tokenEndpoint,
            oauthAuthUrl: oauthResult.metadata.authEndpoint,
          );
        }
        return streamableResult;
      }

      // 2. Fallback to SSE
      final sseResult = await _trySSE(
        serverUrl: serverUrl,
        authType: authType,
        headers: authHeaders,
      );

      if (sseResult.success) {
        if (oauthResult != null) {
          return ConnectionTestResult(
            success: true,
            message: sseResult.message,
            detectedTransport: sseResult.detectedTransport,
            availableTools: sseResult.availableTools,
            accessToken: oauthResult.token.accessToken,
            refreshToken: oauthResult.token.refreshToken,
            tokenExpiry: oauthResult.token.expiresIn != null
                ? DateTime.now().add(Duration(seconds: oauthResult.token.expiresIn!))
                : null,
            oauthClientId: oauthResult.metadata.clientId,
            oauthTokenUrl: oauthResult.metadata.tokenEndpoint,
            oauthAuthUrl: oauthResult.metadata.authEndpoint,
          );
        }
        return sseResult;
      }

      return ConnectionTestResult(
        success: false,
        message: 'Could not connect using Streamable HTTP or SSE transport',
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Connection failed: $e',
      );
    }
  }

  /// Perform Interactive OAuth flow (DCR + Browser Auth + Token Exchange)
  /// Uses proper MCP Auth Protocol discovery for universal server support
  static Future<OAuthFlowResult?> _performInteractiveOAuth(String serverUrl) async {
    try {
      _logger.info('=== Starting MCP OAuth Flow for $serverUrl ===');

      // STEP 1: Probe server to discover authentication requirements
      _logger.info('1. Probing server to discover auth requirements...');
      final probeUri = Uri.parse(serverUrl);
      final probeRes = await http.post(
        probeUri,
        headers: {'Content-Type': 'application/json'},
        body: '{}',
      );

      if (probeRes.statusCode != 401) {
        _logger.info('Server did not return 401. Status: ${probeRes.statusCode}');
        _logger.info('Server may not require OAuth or uses different auth method.');
        return null;
      }

      // STEP 2: Extract metadata URL from WWW-Authenticate header
      _logger.info('2. Extracting auth metadata URL...');
      final authHeader = probeRes.headers['www-authenticate'];
      if (authHeader == null) {
        _logger.severe('❌ No WWW-Authenticate header found');
        return null;
      }

      // Look for resource_metadata="url"
      final match = RegExp(r'resource_metadata="([^"]+)"').firstMatch(authHeader);
      String metadataUrl;
      if (match == null) {
        // Fallback: Try standard location
        metadataUrl = serverUrl.endsWith('/')
            ? '${serverUrl}.well-known/oauth-protected-resource'
            : '$serverUrl/.well-known/oauth-protected-resource';
        _logger.info('No metadata link in header. Trying fallback: $metadataUrl');
      } else {
        metadataUrl = match.group(1)!;
        _logger.info('Found metadata URL: $metadataUrl');
      }

      // STEP 3: Fetch metadata to discover auth server
      _logger.info('3. Fetching auth metadata...');
      final metadataRes = await http.get(Uri.parse(metadataUrl));
      if (metadataRes.statusCode != 200) {
        _logger.severe('❌ Failed to fetch metadata (Status: ${metadataRes.statusCode})');
        return null;
      }

      final metadata = jsonDecode(metadataRes.body) as Map<String, dynamic>;
      final authServers = metadata['authorization_servers'] as List<dynamic>?;

      if (authServers == null || authServers.isEmpty) {
        _logger.severe('❌ No authorization_servers found in metadata');
        return null;
      }

      final authServerUrl = authServers.first as String;
      _logger.info('✅ Discovered auth server: $authServerUrl');

      // STEP 4: Setup local callback server with DYNAMIC port
      // IMPORTANT: We must create the server FIRST to get the actual port number
      // before doing DCR, because DCR needs the redirect_uri with correct port!
      _logger.info('4. Starting local callback server with dynamic port...');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0); // 0 = dynamic port
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port/callback';
      _logger.info('✅ Callback server listening on $redirectUri (port: $port)');
      String? authCode;

      // STEP 5: Dynamic Client Registration (DCR) with actual redirect_uri
      _logger.info('5. Attempting Dynamic Client Registration...');
      final dcrEndpoint = authServerUrl.endsWith('/') ? '${authServerUrl}register' : '$authServerUrl/register';

      _logger.info('DCR endpoint: $dcrEndpoint');

      final dcrRequest = http.Request('POST', Uri.parse(dcrEndpoint));
      dcrRequest.headers['Content-Type'] = 'application/json';
      dcrRequest.body = jsonEncode({
        'client_name': 'Flutter MCP Client',
        'redirect_uris': [redirectUri], // ✅ Use actual dynamic port!
        'grant_types': ['authorization_code', 'refresh_token'],
        'response_types': ['code'],
        'token_endpoint_auth_method': 'none',
        'application_type': 'native',
        'scope': 'openid',
      });

      String? clientId;
      try {
        final dcrResponse = await dcrRequest.send();
        if (dcrResponse.statusCode == 200 || dcrResponse.statusCode == 201) {
          final dcrBody = await dcrResponse.stream.bytesToString();
          final dcrData = jsonDecode(dcrBody);
          clientId = dcrData['client_id'];
          _logger.info('✅ DCR Success! Client ID: $clientId');
          _logger.info('DCR Response: $dcrBody');
        } else {
          final errorBody = await dcrResponse.stream.bytesToString();
          _logger.severe('DCR failed: ${dcrResponse.statusCode} - $errorBody');
        }
      } catch (e) {
        _logger.severe('DCR error: $e');
      }

      if (clientId == null) {
        _logger.severe('⚠️ DCR failed, using fallback client ID');
        clientId = 'mcp-client'; // Generic fallback
      }

      // STEP 6: Build OAuth config with proper endpoints
      _logger.info('6. Building OAuth configuration...');
      final authEndpoint = authServerUrl.endsWith('/') ? '${authServerUrl}authorize' : '$authServerUrl/authorize';
      final tokenEndpoint = authServerUrl.endsWith('/') ? '${authServerUrl}token' : '$authServerUrl/token';

      _logger.info('Auth endpoint: $authEndpoint');
      _logger.info('Token endpoint: $tokenEndpoint');

      final oauthConfig = OAuthConfig(
        authorizationEndpoint: authEndpoint,
        tokenEndpoint: tokenEndpoint,
        clientId: clientId,
        redirectUri: redirectUri,
        scopes: ['openid'],
      );

      // STEP 7: Create authorization URL with RESOURCE parameter
      _logger.info('7. Creating authorization URL with resource parameter...');
      final oauthClient = HttpOAuthClient(config: oauthConfig);

      // Get base auth URL
      final authUrl = await oauthClient.getAuthorizationUrl(scopes: ['openid']);

      // Add resource parameter (CRITICAL for MCP servers!)
      final authUri = Uri.parse(authUrl);
      final params = Map<String, dynamic>.from(authUri.queryParameters);
      params['resource'] = serverUrl; // ← THE KEY!
      final finalAuthUri = authUri.replace(queryParameters: params);

      _logger.info('Authorization URL (with resource): $finalAuthUri');
      _logger.info('Opening browser...');

      if (await canLaunchUrl(finalAuthUri)) {
        await launchUrl(finalAuthUri, mode: LaunchMode.externalApplication);
      } else {
        _logger.severe('❌ Could not launch browser');
        await server.close();
        return null;
      }

      // STEP 8: Wait for callback
      _logger.info('8. Waiting for browser callback...');
      await for (HttpRequest request in server) {
        if (request.uri.path == '/callback') {
          authCode = request.uri.queryParameters['code'];
          final error = request.uri.queryParameters['error'];

          if (error != null) {
            _logger.severe('❌ OAuth error: $error');
            _logger.severe('Error description: ${request.uri.queryParameters['error_description']}');
          } else if (authCode != null) {
            _logger.info('✅ Received auth code!');
          }

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(
              '''
              <html>
              <head>
                <script>
                  window.onload = function() {
                    window.close();
                    setTimeout(function() {
                       document.getElementById('msg').innerHTML = 'Authentication ${error != null ? 'failed' : 'successful'}! You can now close this window and return to the app.';
                    }, 1000);
                  };
                </script>
              </head>
              <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h1 style="color: ${error != null ? 'red' : 'green'};">${error != null ? 'Auth Failed!' : 'Auth Successful!'}</h1>
                <p id="msg">Closing window/tab...</p>
                ${error != null ? '<p>Error: ${request.uri.queryParameters['error_description']}</p>' : ''}
                <button onclick="window.close()" style="padding: 10px 20px; font-size: 16px; cursor: pointer;">Close Window</button>
              </body>
              </html>
              ''',
            );
          await request.response.close();
          await server.close();
          break;
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      }

      if (authCode == null) {
        _logger.severe('❌ Failed to get auth code');
        return null;
      }

      // STEP 9: Exchange code for token
      _logger.info('9. Exchanging code for token...');
      final codeVerifier = oauthClient.codeVerifier;
      if (codeVerifier == null) {
        _logger.severe('❌ Code verifier missing');
        return null;
      }

      final token = await oauthClient.exchangeCodeForToken(
        code: authCode,
        codeVerifier: codeVerifier,
      );

      _logger.info('✅ Got access token! (Expires in ${token.expiresIn ?? "unknown"}s)');
      _logger.info('✅ OAuth flow completed successfully!');

      return OAuthFlowResult(
        token: token,
        metadata: OAuthMetadata(
          clientId: clientId,
          tokenEndpoint: tokenEndpoint,
          authEndpoint: authEndpoint,
        ),
      );
    } catch (e, stackTrace) {
      _logger.severe('❌ OAuth flow failed: $e');
      _logger.info('Stack trace: $stackTrace');
      return null;
    }
  }

  /// محاولة الاتصال عبر Streamable HTTP
  static Future<ConnectionTestResult> _tryStreamableHttp({
    required String serverUrl,
    required McpAuthType authType,
    Map<String, String>? headers,
  }) async {
    try {
      final config = McpClient.simpleConfig(
        name: 'Connection Test Client',
        version: '1.0',
        enableDebugLogging: true, // Enable for debugging
      );

      // For connection testing, try without auth first
      // OAuth will be handled during actual connection
      final transportConfig = TransportConfig.streamableHttp(
        baseUrl: serverUrl,
        headers: headers,
        timeout: const Duration(seconds: 10),
      );

      final clientResult = await McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      ).timeout(const Duration(seconds: 15));

      return await clientResult.fold(
        (client) async {
          try {
            // Try to list tools to verify connection
            final tools = await client.listTools().timeout(
              const Duration(seconds: 10),
            );

            final toolNames = tools.map((t) => t.name).toList();

            await _disconnectClient(client);

            return ConnectionTestResult(
              success: true,
              message: 'Connected successfully via Streamable HTTP! Found ${tools.length} tools.',
              detectedTransport: McpTransportType.streamableHttp,
              availableTools: toolNames,
            );
          } catch (e) {
            await _disconnectClient(client);
            return ConnectionTestResult(
              success: false,
              message: 'Connected but failed to list tools: $e',
            );
          }
        },
        (error) async {
          return ConnectionTestResult(
            success: false,
            message: 'Streamable HTTP failed: $error',
          );
        },
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'Streamable HTTP connection error: $e',
      );
    }
  }

  /// Connect to an MCP server, handling token refresh and updates
  static Future<dynamic> connectAndSync(
    McpServerConfig config, {
    Function(McpServerConfig updatedConfig)? onConfigUpdate,
  }) async {
    McpServerConfig currentConfig = config;

    bool tokenRefreshed = false;

    // 1. Check for expiration if OAuth
    if (currentConfig.authType == McpAuthType.oauth &&
        currentConfig.accessToken != null &&
        currentConfig.tokenExpiry != null) {
      if (currentConfig.tokenExpiry!.isBefore(DateTime.now())) {
        _logger.info('Access token expired, attempting refresh...');
        final start = DateTime.now();
        final newToken = await _refreshOAuthToken(currentConfig);
        if (newToken != null) {
          _logger.info('Token refreshed successfully in ${DateTime.now().difference(start).inMilliseconds}ms');
          currentConfig = currentConfig.copyWith(
            accessToken: newToken.accessToken,
            refreshToken: newToken.refreshToken ?? currentConfig.refreshToken, // Keep old refresh token if not rotated
            tokenExpiry: newToken.expiresIn != null ? DateTime.now().add(Duration(seconds: newToken.expiresIn!)) : null,
          );
          tokenRefreshed = true;
          // Notify update
          if (onConfigUpdate != null) {
            onConfigUpdate(currentConfig);
          }
        } else {
          _logger.severe('Failed to refresh token before connection.');
        }
      }
    }

    // 2. Try to connect
    try {
      return await _attemptConnection(currentConfig);
    } catch (e) {
      // 3. If failed with 401 and we haven't refreshed yet, try refreshing
      // Note: McpClient exceptions might not strictly be 401s in Dart's http client depending on wrapper,
      // but we assume authentication failures might look like exceptions or specific error messages.
      // Since McpClient abstracts the transport, we might catch a generic error.
      // A more robust check would inspecting the error. For now, we try refresh on ANY error if we haven't refreshed yet
      // and it looks like it might be auth related or just a blind retry policy for OAuth.

      // Only retry if we have a refresh token and haven't just refreshed
      if (currentConfig.authType == McpAuthType.oauth && currentConfig.refreshToken != null && !tokenRefreshed) {
        _logger.severe('Connection failed (possibly auth), attempting token refresh...');
        final newToken = await _refreshOAuthToken(currentConfig);
        if (newToken != null) {
          currentConfig = currentConfig.copyWith(
            accessToken: newToken.accessToken,
            refreshToken: newToken.refreshToken ?? currentConfig.refreshToken,
            tokenExpiry: newToken.expiresIn != null ? DateTime.now().add(Duration(seconds: newToken.expiresIn!)) : null,
          );
          // Notify update
          if (onConfigUpdate != null) {
            onConfigUpdate(currentConfig);
          }
          // Retry connection
          return await _attemptConnection(currentConfig);
        }
      }
      rethrow;
    }
  }

  /// Internal helper to attempt connection with a specific config
  static Future<dynamic> _attemptConnection(McpServerConfig config) async {
    final clientConfig = McpClient.simpleConfig(
      name: 'McpClient',
      version: '1.0',
    );

    if (config.serverUrl.isEmpty) {
      throw Exception('Missing server URL for networked transport (${config.detectedTransport})');
    }

    Map<String, String>? headers;
    if (config.authType == McpAuthType.oauth && config.accessToken != null) {
      headers = {'Authorization': 'Bearer ${config.accessToken}'};
    }

    if (config.detectedTransport == McpTransportType.sse) {
      final transportConfig = TransportConfig.sse(
        serverUrl: config.serverUrl,
        headers: headers,
      );
      final result = await McpClient.createAndConnect(
        config: clientConfig,
        transportConfig: transportConfig,
      );
      return result.fold(
        (client) => client,
        (error) => throw Exception('Failed to connect via SSE: $error'),
      );
    } else {
      // Default to Streamable HTTP
      _logger.info('Connecting via Streamable HTTP...');
      _logger.info('Server URL: ${config.serverUrl}');
      _logger.info('Headers: $headers');
      final transportConfig = TransportConfig.streamableHttp(
        baseUrl: config.serverUrl,
        headers: headers,
      );
      final result = await McpClient.createAndConnect(
        config: clientConfig,
        transportConfig: transportConfig,
      );
      return result.fold(
        (client) => client,
        (error) => throw Exception('Failed to connect via Streamable HTTP: $error'),
      );
    }
  }

  static Future<OAuthToken?> _refreshOAuthToken(McpServerConfig config) async {
    if (config.refreshToken == null) {
      _logger.severe('Refresh failed: No refresh token available');
      return null;
    }

    // CRITICAL: We MUST have the correct token endpoint saved from initial OAuth flow
    // Do NOT try to guess it from serverUrl - that will be wrong for MCP servers!
    if (config.oauthTokenUrl == null) {
      _logger.severe('ERROR: oauthTokenUrl is required for token refresh but was not saved!');
      _logger.info('This should have been saved during initial OAuth flow.');
      _logger.info('Cannot refresh token without correct token endpoint.');
      return null;
    }

    try {
      final tokenEndpoint = Uri.parse(config.oauthTokenUrl!);
      _logger.info('Refreshing token at: $tokenEndpoint');

      final body = {
        'grant_type': 'refresh_token',
        'refresh_token': config.refreshToken!,
        'client_id': config.oauthClientId ?? 'mcp-client',
      };

      // Add client_secret if available (most public MCP clients won't have this)
      if (config.oauthClientSecret != null) {
        body['client_secret'] = config.oauthClientSecret!;
      }

      final response = await http.post(
        tokenEndpoint,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.info('✅ Token refreshed successfully!');
        return OAuthToken(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'] ?? config.refreshToken, // Keep old if not rotated
          expiresIn: data['expires_in'],
          issuedAt: DateTime.now(),
        );
      } else {
        _logger.severe('❌ Failed to refresh token: ${response.statusCode}');
        _logger.info('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.severe('❌ Error refreshing token: $e');
      return null;
    }
  }

  /// محاولة الاتصال عبر SSE
  static Future<ConnectionTestResult> _trySSE({
    required String serverUrl,
    required McpAuthType authType,
    Map<String, String>? headers,
  }) async {
    try {
      final config = McpClient.simpleConfig(
        name: 'Connection Test Client',
        version: '1.0',
        enableDebugLogging: true,
      );

      // For connection testing, try without auth first
      final transportConfig = TransportConfig.sse(
        serverUrl: serverUrl,
        headers: headers,
      );

      final clientResult = await McpClient.createAndConnect(
        config: config,
        transportConfig: transportConfig,
      ).timeout(const Duration(seconds: 15));

      return await clientResult.fold(
        (client) async {
          try {
            final tools = await client.listTools().timeout(
              const Duration(seconds: 10),
            );

            final toolNames = tools.map((t) => t.name).toList();

            await _disconnectClient(client);

            return ConnectionTestResult(
              success: true,
              message: 'Connected successfully via SSE! Found ${tools.length} tools.',
              detectedTransport: McpTransportType.sse,
              availableTools: toolNames,
            );
          } catch (e) {
            await _disconnectClient(client);
            return ConnectionTestResult(
              success: false,
              message: 'Connected but failed to list tools: $e',
            );
          }
        },
        (error) async {
          return ConnectionTestResult(
            success: false,
            message: 'SSE failed: $error',
          );
        },
      );
    } catch (e) {
      return ConnectionTestResult(
        success: false,
        message: 'SSE connection error: $e',
      );
    }
  }

  static Future<void> _disconnectClient(dynamic client) async {
    try {
      final result = client.disconnect();
      if (result is Future) {
        await result;
      }
    } catch (_) {}
  }
}
