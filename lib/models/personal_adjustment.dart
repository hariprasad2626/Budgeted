import 'package:cloud_firestore/cloud_firestore.dart';

enum AdjustmentType { DEBIT, CREDIT }

class PersonalAdjustment {
  final String id;
  final AdjustmentType type;
  final double amount;
  final DateTime date;
  final String remarks;

  PersonalAdjustment({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
    };
  }

  factory PersonalAdjustment.fromMap(String id, Map<String, dynamic> map) {
    return PersonalAdjustment(
      id: id,
      type: AdjustmentType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AdjustmentType.DEBIT,
      ),
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
    );
  }
}
