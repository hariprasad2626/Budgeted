import 'package:cloud_firestore/cloud_firestore.dart';

class CostCenter {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final String remarks;
  final double defaultPmeAmount; // Every month budget
  final double defaultOteAmount; // Total budget for OTE
  final String pmeStartMonth; // e.g. "2026-01"

  CostCenter({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    this.remarks = '',
    this.defaultPmeAmount = 0.0,
    this.defaultOteAmount = 0.0,
    this.pmeStartMonth = '2026-01',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'remarks': remarks,
      'defaultPmeAmount': defaultPmeAmount,
      'defaultOteAmount': defaultOteAmount,
      'pmeStartMonth': pmeStartMonth,
    };
  }

  factory CostCenter.fromMap(String id, Map<String, dynamic> map) {
    return CostCenter(
      id: id,
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
      defaultPmeAmount: (map['defaultPmeAmount'] as num?)?.toDouble() ?? 0.0,
      defaultOteAmount: (map['defaultOteAmount'] as num?)?.toDouble() ?? 0.0,
      pmeStartMonth: map['pmeStartMonth'] ?? '2026-01',
    );
  }
}
