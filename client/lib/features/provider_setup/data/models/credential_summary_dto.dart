class CredentialSummaryDto {
  final String authMethod;
  final bool hasSecret;
  final String? maskedSecret;
  final String status;
  final String? accountLabel;
  final int? expiresAt;

  const CredentialSummaryDto({
    required this.authMethod,
    required this.hasSecret,
    this.maskedSecret,
    required this.status,
    this.accountLabel,
    this.expiresAt,
  });

  factory CredentialSummaryDto.fromJson(Map<String, dynamic> json) {
    return CredentialSummaryDto(
      authMethod: (json['auth_method'] ?? '').toString(),
      hasSecret: (json['configured'] as bool?) ?? (json['has_secret'] as bool?) ?? false,
      maskedSecret: (json['masked_key_hint'] ?? json['masked_secret'])?.toString(),
      status: (json['status'] ?? 'missing').toString(),
      accountLabel: json['account_label']?.toString(),
      expiresAt: json['expires_at'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'auth_method': authMethod,
    'configured': hasSecret,
    if (maskedSecret != null) 'masked_key_hint': maskedSecret,
    'status': status,
    if (accountLabel != null) 'account_label': accountLabel,
    if (expiresAt != null) 'expires_at': expiresAt,
  };
}
