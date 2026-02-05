import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a budget allocation period for a cost center.
/// Multiple periods can exist and their budgets stack/add together.
class BudgetPeriod {
  final String id;
  final String costCenterId;
  final String name; // e.g., "FY 2025-26", "Q1 Special Budget"
  final String startMonth; // e.g., "2025-04"
  final String endMonth; // e.g., "2026-03"
  final double defaultPmeAmount; // Default monthly PME
  final Map<String, double> monthlyPme; // Month-wise PME overrides
  final Map<String, String> monthlyPmeRemarks; // Remarks for monthly overrides
  final double oteAmount; 
  final DateTime createdAt;
  final bool isActive;
  final String remarks;

  BudgetPeriod({
    required this.id,
    required this.costCenterId,
    required this.name,
    required this.startMonth,
    required this.endMonth,
    required this.defaultPmeAmount,
    this.monthlyPme = const {},
    this.monthlyPmeRemarks = const {},
    this.oteAmount = 0.0,
    required this.createdAt,
    this.isActive = true,
    this.remarks = '',
  });

  /// Get the PME amount for a specific month
  /// Returns the override if exists, otherwise the default
  double getPmeForMonth(String month) {
    return monthlyPme[month] ?? defaultPmeAmount;
  }

  // Cache to avoid repeated date calculations per frame/build
  List<String>? _cachedMonths;

  /// Get list of all months in this period
  List<String> getAllMonths() {
    if (_cachedMonths != null) return _cachedMonths!;
    
    List<String> months = [];
    try {
      final startParts = startMonth.split('-');
      final endParts = endMonth.split('-');
      
      if (startParts.length == 2 && endParts.length == 2) {
        int startYear = int.parse(startParts[0]);
        int startMon = int.parse(startParts[1]);
        int endYear = int.parse(endParts[0]);
        int endMon = int.parse(endParts[1]);

        int currentYear = startYear;
        int currentMon = startMon;

        while (currentYear < endYear || (currentYear == endYear && currentMon <= endMon)) {
          months.add('$currentYear-${currentMon.toString().padLeft(2, '0')}');
          currentMon++;
          if (currentMon > 12) {
            currentMon = 1;
            currentYear++;
          }
          if (months.length > 240) break; // 20 years safety cap
        }
      }
    } catch (e) {
      // Return empty list on parse error
    }
    _cachedMonths = months;
    return months;
  }

  /// Check if a given month falls within this period
  bool includesMonth(String month) {
    try {
      final checkParts = month.split('-');
      final startParts = startMonth.split('-');
      final endParts = endMonth.split('-');
      
      int checkVal = int.parse(checkParts[0]) * 100 + int.parse(checkParts[1]);
      int startVal = int.parse(startParts[0]) * 100 + int.parse(startParts[1]);
      int endVal = int.parse(endParts[0]) * 100 + int.parse(endParts[1]);

      return checkVal >= startVal && checkVal <= endVal;
    } catch (e) {
      return false;
    }
  }

  /// Calculate total PME budget for this period (sum of all months)
  double get totalPmeBudget {
    double total = 0;
    for (String month in getAllMonths()) {
      total += getPmeForMonth(month);
    }
    return total;
  }

  /// Calculate total budget (PME + OTE)
  double get totalBudget => totalPmeBudget + oteAmount;

  /// Number of months in this period
  int get monthCount => getAllMonths().length;

  Map<String, dynamic> toMap() {
    return {
      'costCenterId': costCenterId,
      'name': name,
      'startMonth': startMonth,
      'endMonth': endMonth,
      'defaultPmeAmount': defaultPmeAmount,
      'monthlyPme': monthlyPme,
      'monthlyPmeRemarks': monthlyPmeRemarks,
      'oteAmount': oteAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'remarks': remarks,
    };
  }

  factory BudgetPeriod.fromMap(String id, Map<String, dynamic> map) {
    // Convert monthlyPme from dynamic map
    Map<String, double> pmeMap = {};
    if (map['monthlyPme'] != null) {
      (map['monthlyPme'] as Map<String, dynamic>).forEach((key, value) {
        pmeMap[key] = (value as num).toDouble();
      });
    }

    // Convert monthlyPmeRemarks from dynamic map
    Map<String, String> remarksMap = {};
    if (map['monthlyPmeRemarks'] != null) {
      (map['monthlyPmeRemarks'] as Map<String, dynamic>).forEach((key, value) {
        remarksMap[key] = value.toString();
      });
    }

    return BudgetPeriod(
      id: id,
      costCenterId: map['costCenterId'] ?? '',
      name: map['name'] ?? '',
      startMonth: map['startMonth'] ?? '',
      endMonth: map['endMonth'] ?? '',
      defaultPmeAmount: (map['defaultPmeAmount'] as num?)?.toDouble() ?? 0.0,
      monthlyPme: pmeMap,
      monthlyPmeRemarks: remarksMap,
      oteAmount: (map['oteAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      remarks: map['remarks'] ?? '',
    );
  }

  BudgetPeriod copyWith({
    String? id,
    String? costCenterId,
    String? name,
    String? startMonth,
    String? endMonth,
    double? defaultPmeAmount,
    Map<String, double>? monthlyPme,
    Map<String, String>? monthlyPmeRemarks,
    double? oteAmount,
    DateTime? createdAt,
    bool? isActive,
    String? remarks,
  }) {
    return BudgetPeriod(
      id: id ?? this.id,
      costCenterId: costCenterId ?? this.costCenterId,
      name: name ?? this.name,
      startMonth: startMonth ?? this.startMonth,
      endMonth: endMonth ?? this.endMonth,
      defaultPmeAmount: defaultPmeAmount ?? this.defaultPmeAmount,
      monthlyPme: monthlyPme ?? Map.from(this.monthlyPme),
      monthlyPmeRemarks: monthlyPmeRemarks ?? Map.from(this.monthlyPmeRemarks),
      oteAmount: oteAmount ?? this.oteAmount,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      remarks: remarks ?? this.remarks,
    );
  }
}
