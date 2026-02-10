import 'package:cloud_firestore/cloud_firestore.dart';

enum BudgetType { OTE, PME }

class BudgetCategory {
  final String id;
  final String costCenterId;
  final String category;
  final String subCategory;
  final BudgetType budgetType;
  final double targetAmount; // The budget allotted to this specific category
  final bool isActive;
  final String remarks;
  final DateTime createdAt;

  BudgetCategory({
    required this.id,
    required this.costCenterId,
    required this.category,
    required this.subCategory,
    required this.budgetType,
    this.targetAmount = 0.0,
    required this.isActive,
    required this.remarks,
    required this.createdAt,
  });

  // Getter for UI compatibility
  String get name => category;
  double get amount => targetAmount;
  DateTime get date => createdAt;

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'category': category,
      'subCategory': subCategory,
      'budgetType': budgetType.toString().split('.').last,
      'targetAmount': targetAmount,
      'isActive': isActive,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BudgetCategory.fromMap(String id, Map<String, dynamic> map) {
    return BudgetCategory(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      category: map['category'] ?? '',
      subCategory: map['subCategory'] ?? '',
      budgetType: BudgetType.values.firstWhere(
        (e) => e.toString().split('.').last == map['budgetType'],
        orElse: () => BudgetType.OTE,
      ),
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      isActive: map['isActive'] ?? true,
      remarks: map['remarks'] ?? '',
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : (map['createdAt'] is String ? DateTime.parse(map['createdAt']) : DateTime.now()),
    );
  }
}
