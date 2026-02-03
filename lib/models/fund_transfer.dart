import 'package:cloud_firestore/cloud_firestore.dart';

class FundTransfer {
  final String id;
  final String costCenterId;
  final double amount;
  final DateTime date;
  final String remarks;

  FundTransfer({
    required this.id,
    required this.costCenterId,
    required this.amount,
    required this.date,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
    };
  }

  factory FundTransfer.fromMap(String id, Map<String, dynamic> map) {
    return FundTransfer(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
    );
  }
}
