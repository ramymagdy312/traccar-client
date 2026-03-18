import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_token.dart';

class AuthApi {
  final http.Client _client;
  final Uri _endpoint;

  AuthApi({
    http.Client? client,
    Uri? endpoint,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint ?? Uri.parse('https://fleet.hoppataxi.com/Account/getAuthToken');

  Future<AuthToken> login({
    required String username,
    required String password,
    String userImei = '',
  }) async {
    final response = await _client.post(
      _endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'UserIEMI': userImei,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed (${response.statusCode})');
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    final token = AuthToken.fromJson(json);
    if (!token.isValid) {
      throw Exception(token.error?.isNotEmpty == true ? token.error : 'Invalid credentials');
    }
    return token;
  }
}

