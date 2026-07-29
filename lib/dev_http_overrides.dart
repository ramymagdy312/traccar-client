import 'dart:io';

import 'api/dio_client.dart';

/// Accepts incomplete / self-signed certificate chains only for
/// [DioClient.trustedHosts] (e.g. fleet.hoppataxi.com).
class TrustedHostHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) =>
            DioClient.isTrustedHost(host);
    return client;
  }
}
