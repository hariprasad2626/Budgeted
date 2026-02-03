import 'package:cloud_firestore/cloud_firestore.dart';

class FixedAmount {
  final String id;
  final String remarks;
  final double amount;
  final DateTime createdAt;

  FixedAmount({
    required this.id,
    required this.remarks,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'remarks': remarks,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FixedAmount.fromMap(String id, Map<String, dynamic> map) {
    DateTime date;
    final dynamic rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return FixedAmount(
      id: id,
      remarks: map['remarks'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      createdAt: date,
    );
  }
}
