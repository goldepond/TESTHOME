import 'package:flutter/material.dart';

class ChecklistItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final ChecklistStatus status;
  final String? uploadedFileUrl;
  final String? uploadedFileName;
  final DateTime? uploadedAt;
  final String? uploadedBy;
  final String? rejectionReason;
  final DateTime? lastUpdated;
  final String? ipAddress;

  ChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.status = ChecklistStatus.pending,
    this.uploadedFileUrl,
    this.uploadedFileName,
    this.uploadedAt,
    this.uploadedBy,
    this.rejectionReason,
    this.lastUpdated,
    this.ipAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'status': status.toString(),
      'uploadedFileUrl': uploadedFileUrl,
      'uploadedFileName': uploadedFileName,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'uploadedBy': uploadedBy,
      'rejectionReason': rejectionReason,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'ipAddress': ipAddress,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      status: ChecklistStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => ChecklistStatus.pending,
      ),
      uploadedFileUrl: map['uploadedFileUrl'],
      uploadedFileName: map['uploadedFileName'],
      uploadedAt: map['uploadedAt'] != null ? DateTime.parse(map['uploadedAt']) : null,
      uploadedBy: map['uploadedBy'],
      rejectionReason: map['rejectionReason'],
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated']) : null,
      ipAddress: map['ipAddress'],
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    ChecklistStatus? status,
    String? uploadedFileUrl,
    String? uploadedFileName,
    DateTime? uploadedAt,
    String? uploadedBy,
    String? rejectionReason,
    DateTime? lastUpdated,
    String? ipAddress,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      uploadedFileUrl: uploadedFileUrl ?? this.uploadedFileUrl,
      uploadedFileName: uploadedFileName ?? this.uploadedFileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}

enum ChecklistStatus {
  pending,    // 미제출
  submitted,  // 제출됨
  rejected,   // 보완필요
  approved,   // 승인됨
}

extension ChecklistStatusExtension on ChecklistStatus {
  String get displayName {
    switch (this) {
      case ChecklistStatus.pending:
        return '미제출';
      case ChecklistStatus.submitted:
        return '제출됨';
      case ChecklistStatus.rejected:
        return '보완필요';
      case ChecklistStatus.approved:
        return '승인됨';
    }
  }

  Color get color {
    switch (this) {
      case ChecklistStatus.pending:
        return Colors.grey;
      case ChecklistStatus.submitted:
        return Colors.blue;
      case ChecklistStatus.rejected:
        return Colors.red;
      case ChecklistStatus.approved:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (this) {
      case ChecklistStatus.pending:
        return Icons.pending;
      case ChecklistStatus.submitted:
        return Icons.upload_file;
      case ChecklistStatus.rejected:
        return Icons.error;
      case ChecklistStatus.approved:
        return Icons.check_circle;
    }
  }
}
