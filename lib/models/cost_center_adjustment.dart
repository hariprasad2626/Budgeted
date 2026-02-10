import 'package:cloud_firestore/cloud_firestore.dart';
import 'budget_category.dart';

import 'personal_adjustment.dart';

class CostCenterAdjustment {
  final String id;
  final String costCenterId;
  final String categoryId; // To which category this adjustment applies
  final AdjustmentType type;
  final double amount;
  final DateTime date;
  final String remarks;
  final BudgetType budgetType;

  CostCenterAdjustment({
    required this.id,
    required this.costCenterId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    required this.remarks,
    required this.budgetType,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'categoryId': categoryId,
      'type': type.toString().split('.').last,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
      'budgetType': budgetType.toString().split('.').last,
    };
  }

  factory CostCenterAdjustment.fromMap(String id, Map<String, dynamic> map) {
    return CostCenterAdjustment(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      type: AdjustmentType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AdjustmentType.DEBIT,
      ),
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : (map['date'] is String ? DateTime.parse(map['date']) : DateTime.now()),
      remarks: map['remarks'] ?? '',
      budgetType: BudgetType.values.firstWhere(
        (e) => e.toString().split('.').last == map['budgetType'],
        orElse: () => BudgetType.OTE,
      ),
    );
  }
}
