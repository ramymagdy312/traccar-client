import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import 'auth_token.dart';

class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();

  @override
  String toString() => 'Invalid credentials';
}

class AuthApi {
  final Dio _dio;
  final String _loginPath;
  final String _refreshPath;

  AuthApi({
    Dio? dio,
    String loginPath = '/Account/getAuthToken',
    String refreshPath = '/Account/RefreshToken',
  })  : _dio = dio ?? DioClient.instance,
        _loginPath = loginPath,
        _refreshPath = refreshPath;

  static final Options _skipAuthOptions = Options(
    extra: const {DioClient.skipAuthKey: true},
  );

  Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        _loginPath,
        data: {'username': username, 'password': password},
        options: _skipAuthOptions,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw Exception('Login failed${status != null ? ' ($status)' : ''}');
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Unexpected response format');
    }

    final payload = Map<String, dynamic>.from(data);
    final token = AuthToken.fromJson(payload);
    if (!token.isValid) {
      if (_isAuthenticationFailure(payload, token)) {
        throw const InvalidCredentialsException();
      }
      throw Exception(token.error?.isNotEmpty == true ? token.error : 'Login failed');
    }
    return token;
  }

  bool _isAuthenticationFailure(Map<String, dynamic> payload, AuthToken token) {
    final hasMissingAccessToken = token.accessToken.isEmpty;
    final hasInvalidUserState = (token.userId ?? 0) <= 0;
    final hasInvalidRepState = (token.repId ?? 0) <= 0;
    final hasAuthFailureError = _looksLikeAuthFailure(
      (payload['Error'] ?? payload['error'])?.toString(),
    );

    return hasMissingAccessToken &&
        (hasAuthFailureError || hasInvalidUserState || hasInvalidRepState);
  }

  bool _looksLikeAuthFailure(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return false;
    return value.contains('auth') ||
        value.contains('login') ||
        value.contains('credential') ||
        value.contains('username') ||
        value.contains('password') ||
        value.contains('unauthor');
  }

  /// Refresh the access token using the refresh-token cookie that was
  /// automatically stored by [DioClient]'s cookie jar during login.
  Future<AuthToken> refreshToken() async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        _refreshPath,
        data: const <String, dynamic>{},
        options: _skipAuthOptions,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      throw Exception(
        'Refresh token failed${status != null ? ' ($status)' : ''}',
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('Unexpected refresh response format');
    }

    final token = AuthToken.fromJson(Map<String, dynamic>.from(data));
    if (!token.isValid) {
      throw Exception(
        token.error?.isNotEmpty == true ? token.error : 'Invalid refresh token',
      );
    }
    return token;
  }
}
