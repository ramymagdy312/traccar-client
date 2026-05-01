import 'package:dio/dio.dart';

import '../models/service_order.dart';
import 'dio_client.dart';

class FleetApi {
  final Dio _dio;

  FleetApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  /// GET service orders for the given date range.
  /// [dateFrom] e.g. "16/03/2026" (dd/MM/yyyy).
  /// [dateTo] e.g. "18/03/2026".
  Future<List<ServiceOrder>> getServiceOrders({
    required String dateFrom,
    required String dateTo,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/Traker/service-orders',
        queryParameters: {'DateFrom': dateFrom, 'DateTo': dateTo},
      );
    } on DioException catch (e) {
      throw _translateDioError(e, fallback: 'فشل تحميل التشغيلات');
    }

    final data = response.data;
    if (data is! List) {
      throw Exception('صيغة استجابة غير متوقعة');
    }

    return data
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
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/Tracker/TransferTrackerInsert',
        data: {
          'Rep_Id': repId,
          'S_O_Sub_Id': sOSubId,
          'Status': status,
          'StartMeter': startMeter,
          'EndMeter': endMeter,
        },
      );
    } on DioException catch (e) {
      throw _translateDioError(e, fallback: 'فشل تحديث الحالة');
    }

    final data = response.data;
    if (data is! Map) {
      throw Exception('صيغة استجابة غير متوقعة');
    }
    final map = Map<String, dynamic>.from(data);
    final success = map['success'] == true;
    if (!success) {
      final message = map['msg'] as String? ??
          map['message'] as String? ??
          map['Message'] as String?;
      throw Exception(message ?? 'فشل تحديث الحالة');
    }
  }

  Exception _translateDioError(DioException e, {required String fallback}) {
    final status = e.response?.statusCode;
    if (status == 401) {
      return Exception('انتهت الجلسة، سجّل الدخول مرة أخرى');
    }
    return Exception('$fallback${status != null ? ' ($status)' : ''}');
  }
}
