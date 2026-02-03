import 'package:cloud_firestore/cloud_firestore.dart';
import 'budget_category.dart';

class BudgetAllocation {
  final String id;
  final String costCenterId;
  final BudgetType budgetType;
  final double amount;
  final String? month; // Required for PME
  final DateTime date;
  final String remarks;

  BudgetAllocation({
    required this.id,
    required this.costCenterId,
    required this.budgetType,
    required this.amount,
    this.month,
    required this.date,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'budgetType': budgetType.name,
      'amount': amount,
      'month': month,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
    };
  }

  factory BudgetAllocation.fromMap(String id, Map<String, dynamic> map) {
    return BudgetAllocation(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      budgetType: BudgetType.values.firstWhere(
        (e) => e.name == map['budgetType'],
        orElse: () => BudgetType.OTE,
      ),
      amount: (map['amount'] as num).toDouble(),
      month: map['month'],
      date: (map['date'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
    );
  }
}
