import 'package:cloud_firestore/cloud_firestore.dart';

enum DonationMode { MERGE_TO_BUDGET, WALLET }

class Donation {
  final String id;
  final String costCenterId;
  final double amount;
  final DonationMode mode;
  final String? budgetCategoryId;
  final DateTime date;
  final String remarks;

  Donation({
    required this.id,
    required this.costCenterId,
    required this.amount,
    required this.mode,
    this.budgetCategoryId,
    required this.date,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'amount': amount,
      'mode': mode.name,
      'budgetCategoryId': budgetCategoryId,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
    };
  }

  factory Donation.fromMap(String id, Map<String, dynamic> map) {
    return Donation(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      mode: DonationMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => DonationMode.WALLET,
      ),
      budgetCategoryId: map['budgetCategoryId'],
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : (map['date'] is String ? DateTime.parse(map['date']) : DateTime.now()),
      remarks: map['remarks'] ?? '',
    );
  }
}
