class AuthToken {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final int? userId;
  final int? repId;
  final String? userName;
  final int? companyId;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? error;

  AuthToken({
    required this.accessToken,
    this.tokenType = 'bearer',
    this.expiresIn,
    this.userId,
    this.repId,
    this.userName,
    this.companyId,
    this.issuedAt,
    this.expiresAt,
    this.error,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['userId'] ?? json['User_Id'];
    final parsedUserId = rawUserId is num ? rawUserId.toInt() : int.tryParse('$rawUserId');
    final rawRepId = json['Rep_Id'];
    final parsedRepId = rawRepId is num ? rawRepId.toInt() : int.tryParse('$rawRepId');
    return AuthToken(
      accessToken: (json['access_token'] as String?) ?? '',
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      userId: parsedUserId,
      repId: parsedRepId,
      userName: json['userName'] as String?,
      companyId: (json['Company_Id'] as num?)?.toInt(),
      issuedAt: DateTime.tryParse((json['issued'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((json['expires'] as String?) ?? ''),
      error: json['Error'] as String?,
    );
  }

  bool get isValid =>
      accessToken.isNotEmpty && (error == null || error!.isEmpty);
}
