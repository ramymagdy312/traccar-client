class AuthToken {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final String? userName;
  final int? userId;
  final int? companyId;
  final String? error;

  const AuthToken({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.userName,
    this.userId,
    this.companyId,
    this.error,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: (json['access_token'] as String?) ?? '',
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      userName: json['userName'] as String?,
      userId: (json['userId'] as num?)?.toInt(),
      companyId: (json['Company_Id'] as num?)?.toInt(),
      error: json['Error'] as String?,
    );
  }

  bool get isValid => accessToken.isNotEmpty && (error == null || error!.isEmpty);
}

