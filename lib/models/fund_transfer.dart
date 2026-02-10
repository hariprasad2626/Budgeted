import 'package:cloud_firestore/cloud_firestore.dart';

enum TransferType { TO_PERSONAL, CATEGORY_TO_CATEGORY }

class FundTransfer {
  final String id;
  final String costCenterId;
  final double amount;
  final DateTime date;
  final String remarks;
  final TransferType type;
  
  // Optional for Category-to-Category transfers
  final String? fromCategoryId;
  final String? toCategoryId; // If null, it can mean "Unallocated" (Wallet)
  
  FundTransfer({
    required this.id,
    required this.costCenterId,
    required this.amount,
    required this.date,
    required this.remarks,
    this.type = TransferType.TO_PERSONAL,
    this.fromCategoryId,
    this.toCategoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'remarks': remarks,
      'type': type.toString().split('.').last,
      'fromCategoryId': fromCategoryId,
      'toCategoryId': toCategoryId,
    };
  }

  factory FundTransfer.fromMap(String id, Map<String, dynamic> map) {
    TransferType tType = TransferType.TO_PERSONAL;
    try {
      final typeStr = map['type'] as String?;
      if (typeStr != null) {
        tType = TransferType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => TransferType.TO_PERSONAL,
        );
      }
    } catch (_) {}

    return FundTransfer(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] is Timestamp 
          ? (map['date'] as Timestamp).toDate() 
          : (map['date'] is String ? DateTime.parse(map['date']) : DateTime.now()),
      remarks: map['remarks'] ?? '',
      type: tType,
      fromCategoryId: map['fromCategoryId'],
      toCategoryId: map['toCategoryId'],
    );
  }
}
