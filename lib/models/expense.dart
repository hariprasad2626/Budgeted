import 'package:cloud_firestore/cloud_firestore.dart';
import 'budget_category.dart';

enum MoneySource { PERSONAL, WALLET, ISKCON }

class Expense {
  final String id;
  final String costCenterId;
  final String categoryId;
  final double amount;
  final BudgetType budgetType;
  final MoneySource moneySource;
  final DateTime date;
  final String remarks;
  final bool isSettled;

  Expense({
    required this.id,
    required this.costCenterId,
    required this.categoryId,
    required this.amount,
    required this.budgetType,
    required this.moneySource,
    required this.date,
    required this.remarks,
    this.isSettled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'categoryId': categoryId,
      'amount': amount,
      'budgetType': budgetType.toString().split('.').last,
      'moneySource': moneySource.toString().split('.').last,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
      'isSettled': isSettled,
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      categoryId: map['categoryId'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      budgetType: BudgetType.values.firstWhere(
        (e) => e.toString().split('.').last == map['budgetType'],
        orElse: () => BudgetType.OTE,
      ),
      moneySource: MoneySource.values.firstWhere(
        (e) => e.toString().split('.').last == map['moneySource'],
        orElse: () => MoneySource.PERSONAL,
      ),
      date: (map['date'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
      isSettled: map['isSettled'] ?? false,
    );
  }
}
