import 'package:cloud_firestore/cloud_firestore.dart';

/// 신고 사유
enum ReportReason {
  appBypass,   // 앱 보고 따로 연락해 옴
  fakeVisit,   // 허위 방문 요청
  falseInfo,   // 부정확한 정보 제공
  other,       // 기타
}

extension ReportReasonExtension on ReportReason {
  String get label {
    switch (this) {
      case ReportReason.appBypass:
        return '앱 보고 따로 연락해 옴';
      case ReportReason.fakeVisit:
        return '허위 방문 요청';
      case ReportReason.falseInfo:
        return '부정확한 정보 제공';
      case ReportReason.other:
        return '기타';
    }
  }

  String get description {
    switch (this) {
      case ReportReason.appBypass:
        return '수수료만 챙기고 책임은 지지 않으려는 행위입니다';
      case ReportReason.fakeVisit:
        return '실제로 방문할 의사 없이 요청한 경우';
      case ReportReason.falseInfo:
        return '거짓된 견적이나 정보를 제공한 경우';
      case ReportReason.other:
        return '기타 문제가 있는 경우';
    }
  }

  String get value {
    switch (this) {
      case ReportReason.appBypass:
        return 'app_bypass';
      case ReportReason.fakeVisit:
        return 'fake_visit';
      case ReportReason.falseInfo:
        return 'false_info';
      case ReportReason.other:
        return 'other';
    }
  }

  static ReportReason fromValue(String value) {
    switch (value) {
      case 'app_bypass':
        return ReportReason.appBypass;
      case 'fake_visit':
        return ReportReason.fakeVisit;
      case 'false_info':
        return ReportReason.falseInfo;
      case 'other':
      default:
        return ReportReason.other;
    }
  }
}

/// 신고 모델
class Report {
  final String id;
  final String reporterId;
  final String reporterName;
  final String brokerId;
  final String brokerName;
  final String? brokerRegistrationNumber;
  final ReportReason reason;
  final String? description;
  final String? propertyId;
  final String status; // pending, resolved, dismissed
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminNotes;

  Report({
    required this.reporterId,
    required this.reporterName,
    required this.brokerId,
    required this.brokerName,
    required this.reason,
    this.id = '',
    this.brokerRegistrationNumber,
    this.description,
    this.propertyId,
    this.status = 'pending',
    DateTime? createdAt,
    this.updatedAt,
    this.adminNotes,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerRegistrationNumber': brokerRegistrationNumber,
      'reason': reason.value,
      'description': description,
      'propertyId': propertyId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminNotes': adminNotes,
    };
  }

  factory Report.fromMap(String id, Map<String, dynamic> map) {
    return Report(
      id: id,
      reporterId: map['reporterId'] ?? '',
      reporterName: map['reporterName'] ?? '',
      brokerId: map['brokerId'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerRegistrationNumber: map['brokerRegistrationNumber'],
      reason: ReportReasonExtension.fromValue(map['reason'] ?? 'other'),
      description: map['description'],
      propertyId: map['propertyId'],
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      adminNotes: map['adminNotes'],
    );
  }

  Report copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    String? brokerId,
    String? brokerName,
    String? brokerRegistrationNumber,
    ReportReason? reason,
    String? description,
    String? propertyId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminNotes,
  }) {
    return Report(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerRegistrationNumber: brokerRegistrationNumber ?? this.brokerRegistrationNumber,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      propertyId: propertyId ?? this.propertyId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminNotes: adminNotes ?? this.adminNotes,
    );
  }
}
