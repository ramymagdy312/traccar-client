import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_storage.dart';
import '../auth/session_manager.dart';

/// Centralized Dio HTTP client with:
///  * Persistent cookie jar (refresh-token cookie survives restarts, sent automatically).
///  * Self-signed SSL bypass for trusted hosts.
///  * Auth interceptor that injects Bearer tokens and transparently refreshes
///    them via [SessionManager] on 401 responses.
class DioClient {
  DioClient._();

  static const String baseUrl = 'https://fleet.hoppataxi.com';
  static const Set<String> trustedHosts = {'fleet.hoppataxi.com'};

  /// Whether [host] is allow-listed for incomplete / self-signed SSL chains.
  static bool isTrustedHost(String host) => trustedHosts.contains(host);

  /// Marker for requests that must NOT go through the auth interceptor
  /// (login, refresh). Set as `Options(extra: {DioClient.skipAuthKey: true})`.
  static const String skipAuthKey = 'skipAuth';

  /// Marker used by the interceptor to prevent infinite retry loops.
  static const String _retriedKey = 'retried';

  static Dio? _dio;
  static PersistCookieJar? _cookieJar;

  /// Must be called once during app startup before any API call.
  static Future<void> init() async {
    if (_dio != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final jarDir = Directory('${docsDir.path}/.cookies');
    if (!jarDir.existsSync()) {
      jarDir.createSync(recursive: true);
    }
    _cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage(jarDir.path),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.json,
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (cert, host, port) => isTrustedHost(host);
        return client;
      },
      validateCertificate: (cert, host, port) => isTrustedHost(host),
    );

    dio.interceptors.add(CookieManager(_cookieJar!));
    dio.interceptors.add(_AuthInterceptor(dio));

    _dio = dio;
  }

  static Dio get instance {
    final dio = _dio;
    if (dio == null) {
      throw StateError('DioClient.init() must be called before use.');
    }
    return dio;
  }

  static CookieJar get cookieJar {
    final jar = _cookieJar;
    if (jar == null) {
      throw StateError('DioClient.init() must be called before use.');
    }
    return jar;
  }

  /// Clear all stored cookies (e.g., on logout).
  static Future<void> clearCookies() async {
    await _cookieJar?.deleteAll();
  }
}

/// Injects `Authorization: Bearer <token>` and, on 401, triggers a single
/// session refresh and retries the request. Implemented as a
/// [QueuedInterceptor] so concurrent requests all wait on one refresh.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  final AuthStorage _storage = const AuthStorage();

  bool _shouldSkip(RequestOptions options) =>
      options.extra[DioClient.skipAuthKey] == true;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkip(options)) {
      return handler.next(options);
    }
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = request.extra[DioClient._retriedKey] == true;

    if (!is401 || alreadyRetried || _shouldSkip(request)) {
      return handler.next(err);
    }

    final refreshed = await SessionManager.extendSession();
    if (!refreshed) {
      return handler.next(err);
    }

    final newToken = await _storage.readAccessToken();
    if (newToken == null || newToken.isEmpty) {
      return handler.next(err);
    }

    request.headers['Authorization'] = 'Bearer $newToken';
    request.extra[DioClient._retriedKey] = true;

    try {
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
