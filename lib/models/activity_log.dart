import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityType { CREATE, UPDATE, DELETE }
enum EntityType { EXPENSE, DONATION, TRANSFER, ADJUSTMENT, CATEGORY, ALLOCATION, FIXED_AMOUNT, BUDGET_PERIOD }

class ActivityLog {
  final String id;
  final ActivityType activityType;
  final EntityType entityType;
  final String entityId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final DateTime timestamp;
  final String remarks;

  ActivityLog({
    required this.id,
    required this.activityType,
    required this.entityType,
    required this.entityId,
    this.oldData,
    this.newData,
    required this.timestamp,
    required this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'activityType': activityType.name,
      'entityType': entityType.name,
      'entityId': entityId,
      'oldData': oldData,
      'newData': newData,
      'timestamp': Timestamp.fromDate(timestamp),
      'remarks': remarks,
    };
  }

  factory ActivityLog.fromMap(String id, Map<String, dynamic> map) {
    return ActivityLog(
      id: id,
      activityType: ActivityType.values.firstWhere((e) => e.name == map['activityType']),
      entityType: EntityType.values.firstWhere((e) => e.name == map['entityType']),
      entityId: map['entityId'] ?? '',
      oldData: map['oldData'],
      newData: map['newData'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      remarks: map['remarks'] ?? '',
    );
  }
}
