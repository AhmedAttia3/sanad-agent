import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

import 'package:sanad_client/core/config/app_config.dart';

/// A start/status payload returned by the portal ``/auth/start`` endpoint.
///
/// The portal decides whether the flow needs a ``userCode`` (CLI/headless
/// fallback) based on ``platform`` and ``capabilities``. The client never
/// picks a flow by name (no ``device-code`` / ``mobile-pkce``) and never names
/// an identity provider.
class PortalAuthStart {
  final String authSessionId;
  final String pollingToken;
  final String authUrl;
  final int expiresIn;
  final int interval;
  final String? userCode;

  const PortalAuthStart({
    required this.authSessionId,
    required this.pollingToken,
    required this.authUrl,
    required this.expiresIn,
    required this.interval,
    required this.userCode,
  });

  factory PortalAuthStart.fromJson(Map<String, dynamic> json) {
    return PortalAuthStart(
      authSessionId: json['auth_session_id'] as String,
      pollingToken: json['polling_token'] as String,
      authUrl: json['auth_url'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 300,
      interval: (json['interval'] as num?)?.toInt() ?? 2,
      userCode: json['user_code'] as String?,
    );
  }
}

/// Auth session status as reported by ``/auth/status``.
class PortalAuthStatus {
  final String status;
  final String? accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;

  const PortalAuthStatus({
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory PortalAuthStatus.fromJson(Map<String, dynamic> json) {
    return PortalAuthStatus(
      status: json['status'] as String,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String?,
      expiresIn: (json['expires_in'] as num?)?.toInt(),
    );
  }
}

class PortalAuthRefresh {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;

  const PortalAuthRefresh({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
  });

  factory PortalAuthRefresh.fromJson(Map<String, dynamic> json) {
    return PortalAuthRefresh(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
    );
  }
}

/// Backend-agnostic portal auth client.
///
/// Talks ONLY to ``sanad-portal`` public endpoints:
///   - ``POST {portalUrl}/auth/start``
///   - ``POST {portalUrl}/auth/status``
///   - ``POST {portalUrl}/auth/cancel``
///   - ``POST {portalUrl}/auth/refresh``
///   - ``POST {portalUrl}/auth/logout``
///
/// The client knows nothing about identity providers, OAuth, device codes,
/// or backend URLs for authentication. The portal decides the rest.
class PortalAuthClient {
  static final _logger = Logger('PortalAuthClient');

  final Dio _dio;

  PortalAuthClient({Dio? dio})
    : _dio =
          dio ??
          (Dio()
            ..options.connectTimeout = const Duration(seconds: 5)
            ..options.receiveTimeout = const Duration(seconds: 5));

  /// Resolve the portal URL. Falls back to [AppConfig.portalUrl].
  static String get portalUrl => AppConfig.portalUrl;

  String _url(String path) => '${portalUrl.replaceAll(RegExp(r'/+$'), '')}$path';

  /// Start a portal auth session.
  ///
  /// [platform] is a generic platform hint (e.g. ``desktop``, ``cli``, ``web``,
  /// ``android``, ``ios``). [capabilities] is an optional list of non-sensitive
  /// client capabilities the portal may use to pick a UX (e.g. ``popup``,
  /// ``system_browser``, ``deep_link``).
  ///
  /// The client MUST NOT pass a provider name or a flow identifier.
  Future<PortalAuthStart> start({
    required String platform,
    List<String>? capabilities,
    String? returnUri,
  }) async {
    final response = await _dio.post(
      _url('/auth/start'),
      data: {
        'platform': platform,
        if (capabilities != null && capabilities.isNotEmpty) 'capabilities': capabilities,
        if (returnUri != null) 'return_uri': returnUri,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to start portal auth session.');
    }
    return PortalAuthStart.fromJson(response.data as Map<String, dynamic>);
  }

  /// Poll status using the private ``pollingToken`` returned by [start].
  Future<PortalAuthStatus> status({
    required String authSessionId,
    required String pollingToken,
  }) async {
    final response = await _dio.post(
      _url('/auth/status'),
      data: {
        'auth_session_id': authSessionId,
        'polling_token': pollingToken,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to poll portal auth status.');
    }
    return PortalAuthStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Cancel an in-progress auth session.
  Future<void> cancel({
    required String authSessionId,
    required String pollingToken,
  }) async {
    try {
      await _dio.post(
        _url('/auth/cancel'),
        data: {
          'auth_session_id': authSessionId,
          'polling_token': pollingToken,
        },
      );
    } catch (e) {
      _logger.warning('Portal auth cancel failed: $e');
    }
  }

  /// Refresh an access token through the portal.
  Future<PortalAuthRefresh> refresh({required String refreshToken}) async {
    final response = await _dio.post(
      _url('/auth/refresh'),
      data: {'refresh_token': refreshToken},
    );
    if (response.statusCode != 200) {
      throw Exception('Portal auth refresh failed.');
    }
    return PortalAuthRefresh.fromJson(response.data as Map<String, dynamic>);
  }

  /// Best-effort logout through the portal.
  Future<void> logout({String? accessToken, String? refreshToken}) async {
    try {
      await _dio.post(
        _url('/auth/logout'),
        data: {
          if (accessToken != null) 'access_token': accessToken,
          if (refreshToken != null) 'refresh_token': refreshToken,
        },
      );
    } catch (e) {
      _logger.warning('Portal auth logout failed: $e');
    }
  }
}
