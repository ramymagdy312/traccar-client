import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_storage.dart';
import '../models/service_order.dart';

class FleetApi {
  static const String _baseUrl = 'https://fleet.hoppataxi.com';
  final http.Client _client;
  final AuthStorage _authStorage;

  FleetApi({
    http.Client? client,
    AuthStorage? authStorage,
  })  : _client = client ?? http.Client(),
        _authStorage = authStorage ?? const AuthStorage();

  Future<String?> _getToken() => _authStorage.readAccessToken();

  /// GET service orders for the given rep and date range.
  /// [repId] Rep_ID (e.g. from login userId).
  /// [dateFrom] e.g. "16/03/2026" (dd/MM/yyyy).
  /// [dateTo] e.g. "18/03/2026".
  /// [sOMainId] usually 0 to get all.
  Future<List<ServiceOrder>> getServiceOrders({
    required int repId,
    required String dateFrom,
    required String dateTo,
    int sOMainId = 0,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('غير مسجل الدخول');
    }

    final uri = Uri.parse('$_baseUrl/Traker/GetServiceOrder_ByRepMan_ExceptThis');
    final body = jsonEncode({
      'Rep_ID': repId,
      'DateFrom': dateFrom,
      'DateTo': dateTo,
      'S_O_Main_Id': sOMainId,
    });

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception('انتهت الجلسة، سجّل الدخول مرة أخرى');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل تحميل التشغيلات (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('صيغة استجابة غير متوقعة');
    }

    return decoded
        .map((e) => ServiceOrder.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Update service status: start (status=1) or end (status=2).
  /// [repId] Rep_Id from login.
  /// [sOSubId] S_O_Sub_Id of the service order.
  /// [status] 1 = start, 2 = end.
  /// [startMeter] odometer at start (when status==1); use 0 when status==2.
  /// [endMeter] odometer at end (when status==2); use 0 when status==1.
  Future<void> updateServiceStatus({
    required int repId,
    required int sOSubId,
    required int status,
    required int startMeter,
    required int endMeter,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('غير مسجل الدخول');
    }

    final uri = Uri.parse('$_baseUrl/Tracker/TransferTrackerInsert');
    final body = jsonEncode({
      'Rep_Id': repId,
      'S_O_Sub_Id': sOSubId,
      'Status': status,
      'StartMeter': startMeter,
      'EndMeter': endMeter,
    });

    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception('انتهت الجلسة، سجّل الدخول مرة أخرى');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل تحديث الحالة (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('صيغة استجابة غير متوقعة');
    }
    final success = decoded['success'] == true;
    if (!success) {
      final message = decoded['msg'] as String? ?? decoded['message'] as String? ?? decoded['Message'] as String?;
      throw Exception(message ?? 'فشل تحديث الحالة');
    }
  }
}
