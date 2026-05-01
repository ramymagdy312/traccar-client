/// Model for a single service order from GetServiceOrder_ByRepMan_ExceptThis API.
class ServiceOrder {
  final int rowNum;
  final String? pickUpDateTimeRaw;
  final DateTime? pickUpDateTime;
  final int sOMainId;
  final int? companyId;
  final String sONo;
  final int? drvNameId;
  final int? vicDtlId;
  final String? suppCode;
  final String? suppName;
  final String sODate;
  final int? sODateNum;
  final String? carNo;
  final String? licenseNo;
  final String? vehCode;
  final int sOSubId;
  final int? custId;
  final String? custCode;
  final String? custName;
  final String? pickupTime;
  final String? localRef;
  final String? transCode;
  final String? transName;
  final int? totalAdlt;
  final int? totalChd;
  final int trackerStatus; // 0=لم يبدأ, 1=قيد التنفيذ, 2=منتهي
  final int? maxKM;

  const ServiceOrder({
    required this.rowNum,
    this.pickUpDateTimeRaw,
    this.pickUpDateTime,
    required this.sOMainId,
    this.companyId,
    required this.sONo,
    this.drvNameId,
    this.vicDtlId,
    this.suppCode,
    this.suppName,
    required this.sODate,
    this.sODateNum,
    this.carNo,
    this.licenseNo,
    this.vehCode,
    required this.sOSubId,
    this.custId,
    this.custCode,
    this.custName,
    this.pickupTime,
    this.localRef,
    this.transCode,
    this.transName,
    this.totalAdlt,
    this.totalChd,
    required this.trackerStatus,
    this.maxKM,
  });

  static int? _parseDateMs(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    final match = RegExp(r'/Date\((\d+)\)/').firstMatch(s);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static int _int(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory ServiceOrder.fromJson(Map<String, dynamic> json) {
    final dateMs = _parseDateMs(json['PickUpDateTime']);
    return ServiceOrder(
      rowNum: _int(json['Row_Num']),
      pickUpDateTimeRaw: json['PickUpDateTime']?.toString(),
      pickUpDateTime: dateMs != null ? DateTime.fromMillisecondsSinceEpoch(dateMs) : null,
      sOMainId: _int(json['S_O_Main_Id']),
      companyId: _intOrNull(json['Company_Id']),
      sONo: (json['S_O_No'] ?? '').toString(),
      drvNameId: _intOrNull(json['Drv_Name_ID']),
      vicDtlId: _intOrNull(json['Vic_Dtl_ID']),
      suppCode: json['Supp_Code']?.toString(),
      suppName: json['Supp_Name']?.toString(),
      sODate: (json['S_O_Date'] ?? '').toString(),
      sODateNum: _intOrNull(json['S_O_DateNum']),
      carNo: json['Car_No']?.toString(),
      licenseNo: json['License_No']?.toString(),
      vehCode: json['Veh_Code']?.toString(),
      sOSubId: _int(json['S_O_Sub_Id']),
      custId: _intOrNull(json['Cust_Id']),
      custCode: json['Cust_Code']?.toString(),
      custName: json['Cust_Name']?.toString(),
      pickupTime: json['PickupTime']?.toString(),
      localRef: json['Local_Ref']?.toString(),
      transCode: json['Trans_Code']?.toString(),
      transName: json['Trans_Name']?.toString(),
      totalAdlt: _intOrNull(json['Total_Adlt']),
      totalChd: _intOrNull(json['Total_Chd']),
      trackerStatus: _int(json['TrackerStatus']),
      maxKM: _intOrNull(json['MaxKM']),
    );
  }

  bool get isNotStarted => trackerStatus == 0;
  bool get isInProgress => trackerStatus == 1;
  bool get isCompleted => trackerStatus == 2;
}
