import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/budget_category.dart';
import '../models/donation.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../services/firestore_service.dart';
import 'add_expense_screen.dart';
import 'add_donation_screen.dart';
import 'add_adjustment_screen.dart';
import 'add_center_adjustment_screen.dart';
import 'add_transfer_screen.dart';
import 'transaction_history_screen.dart';
import '../models/cost_center_adjustment.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedLedgerIds = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        final activeCenter = provider.activeCostCenter;
        if (activeCenter == null) {
          return Scaffold(appBar: AppBar(title: const Text('Ledger')), body: const Center(child: Text('No active center.')));
        }

        // Gather all relevant transactions for this center
        final filterMode = ModalRoute.of(context)?.settings.arguments as String? ?? 'ALL_CENTER'; // 'PME', 'OTE', 'WALLET', 'ADVANCE', 'ALL_CENTER'

        // Calculate unallocated (Gap) amounts for Wallet view
        double earmarkedOte = provider.categories.where((c) => c.budgetType == BudgetType.OTE).fold(0.0, (sum, c) => sum + c.targetAmount);
        double earmarkedPmeMonthly = provider.categories.where((c) => c.budgetType == BudgetType.PME).fold(0.0, (sum, c) => sum + c.targetAmount);

        // Synthetic Budget Entries
        List<Map<String, dynamic>> budgetEntries = [];
        
        if (activeCenter != null && provider.budgetPeriods.isNotEmpty) {
          final activePeriods = provider.budgetPeriods.where((p) => p.isActive).toList();

          // Collect all months from active periods for PME logic
          final Set<String> pmeMonths = {};
          for (var p in activePeriods) {
            pmeMonths.addAll(p.getAllMonths().where((m) => provider.isMonthInPastOrCurrent(m)));
          }
          final sortedMonths = pmeMonths.toList()..sort();

          for (var m in sortedMonths) {
            DateTime monthDate;
            try { monthDate = DateFormat('yyyy-MM').parse(m); } catch (_) { continue; }

            double monthlyBaseline = 0;
            double monthlyBudgeted = 0;
            String? monthRemark;

            for (var p in activePeriods) {
              if (p.includesMonth(m)) {
                monthlyBaseline += p.defaultPmeAmount;
                monthlyBudgeted += p.getPmeForMonth(m);
                if (p.monthlyPmeRemarks.containsKey(m)) {
                  monthRemark = p.monthlyPmeRemarks[m];
                }
              }
            }

            // 1. Monthly PME Credit (Show in PME or ALL)
            if (filterMode == 'PME' || filterMode == 'ALL_CENTER') {
              if (monthlyBudgeted > 0) {
                budgetEntries.add({
                  'type': 'Budget',
                  'source': 'PME Allocation',
                  'amount': monthlyBudgeted,
                  'date': monthDate,
                  'title': 'Monthly PME Allocation',
                  'color': Colors.purpleAccent,
                  'item': null,
                  'budgetType': 'PME',
                  'status': 'Recurring',
                  'statusColor': Colors.purple,
                  'categoryPath': (monthRemark != null && monthRemark.isNotEmpty) ? 'Adj: $monthRemark' : 'Monthly credit',
                });
              }
            }

            // 2. Unallocated PME Surplus (Debit from PME, Credit to Wallet)
            double pmeSurplus = monthlyBudgeted - earmarkedPmeMonthly;
            if (pmeSurplus > 0) {
              if (filterMode == 'WALLET') {
                budgetEntries.add({
                  'type': 'Budget Move',
                  'source': 'Unallocated',
                  'amount': pmeSurplus,
                  'date': monthDate,
                  'title': 'PME Surplus Credit',
                  'color': Colors.amberAccent,
                  'item': null,
                  'budgetType': 'WALLET',
                  'status': 'Received',
                  'statusColor': Colors.amber,
                  'categoryPath': 'Unallocated PME funds',
                });
              } else if (filterMode == 'PME') {
                budgetEntries.add({
                  'type': 'Budget Move',
                  'source': 'Unallocated',
                  'amount': -pmeSurplus,
                  'date': monthDate,
                  'title': 'Move to Wallet (Unallocated)',
                  'color': Colors.grey,
                  'item': null,
                  'budgetType': 'PME',
                  'status': 'Debited',
                  'statusColor': Colors.grey,
                  'categoryPath': 'Sent to General Wallet',
                });
              }
            }

            // 3. PME Reduction Savings (Credit to Wallet only - it's a side pool)
            double savings = monthlyBaseline - monthlyBudgeted;
            if (savings > 0 && filterMode == 'WALLET') {
              budgetEntries.add({
                'type': 'Budget',
                'source': 'System Savings',
                'amount': savings,
                'date': monthDate,
                'title': 'PME Reduction Savings',
                'color': Colors.amberAccent,
                'item': null,
                'budgetType': 'WALLET',
                'status': 'Saved',
                'statusColor': Colors.amber,
                'categoryPath': 'Savings from baseline',
              });
            }
          }

          // 4. OTE Budget and Surplus
          double totalOteBudgeted = activePeriods.fold(0.0, (sum, p) => sum + p.oteAmount);
          if (totalOteBudgeted > 0) {
            DateTime oteDate = DateTime.now(); // We take latest for OTE
             try { 
                final startStr = activePeriods.first.startMonth;
                oteDate = DateFormat('yyyy-MM').parse(startStr);
             } catch (_) {}

            // OTE Credit
            if (filterMode == 'OTE' || filterMode == 'ALL_CENTER') {
              budgetEntries.add({
                'type': 'Budget',
                'source': 'OTE Allocation',
                'amount': totalOteBudgeted,
                'date': oteDate,
                'title': 'OTE Period Budget',
                'color': Colors.tealAccent,
                'item': null,
                'budgetType': 'OTE',
                'status': 'Allocated',
                'statusColor': Colors.teal,
                'categoryPath': 'Full period allocation',
              });
            }

            // OTE Surplus
            double oteSurplus = totalOteBudgeted - earmarkedOte;
            if (oteSurplus > 0) {
              if (filterMode == 'WALLET') {
                 budgetEntries.add({
                    'type': 'Budget Move',
                    'source': 'Unallocated',
                    'amount': oteSurplus,
                    'date': oteDate,
                    'title': 'OTE Surplus Gap',
                    'color': Colors.amberAccent,
                    'item': null,
                    'budgetType': 'WALLET',
                    'status': 'Received',
                    'statusColor': Colors.amber,
                    'categoryPath': 'Unallocated OTE funds',
                  });
              } else if (filterMode == 'OTE') {
                budgetEntries.add({
                    'type': 'Budget Move',
                    'source': 'Unallocated',
                    'amount': -oteSurplus,
                    'date': oteDate,
                    'title': 'Move to Wallet (Unallocated)',
                    'color': Colors.grey,
                    'item': null,
                    'budgetType': 'OTE',
                    'status': 'Debited',
                    'statusColor': Colors.grey,
                    'categoryPath': 'Sent to General Wallet',
                  });
              }
            }
          }
        }

        // Gather all relevant transactions for this center
        List<Map<String, dynamic>> allEntries = [
          ...budgetEntries,
          ...provider.expenses.where((e) => e.moneySource != MoneySource.PERSONAL && e.amount != 0).expand((e) {
                final source = e.moneySource.toString().split('.').last;
                final bType = (e.moneySource == MoneySource.WALLET) ? 'WALLET' : e.budgetType.toString().split('.').last;
                final actualBType = e.budgetType.toString().split('.').last;

                String catName = 'General Wallet';
                try {
                  final cat = provider.categories.firstWhere((c) => c.id == e.categoryId);
                  catName = '${cat.category} -> ${cat.subCategory}';
                } catch (_) {}
                
                final List<Map<String, dynamic>> multi = [];

                // 1. Budget Side (PME/OTE/etc)
                multi.add({
                  'type': 'Expense',
                  'source': source,
                  'amount': -e.amount,
                  'date': e.date,
                  'title': e.remarks,
                  'color': Colors.redAccent,
                  'item': e,
                  'budgetType': actualBType, // This MUST match PME/OTE strings
                  'status': 'Debited',
                  'statusColor': Colors.redAccent,
                  'categoryPath': catName,
                });

                // 2. Wallet Side (If paid from wallet but budget category was PME/OTE)
                // We add a synthetic entry to show in the WALLET view
                if (e.moneySource == MoneySource.WALLET && actualBType != 'WALLET') {
                  multi.add({
                    'type': 'Wallet usage',
                    'source': 'Wallet',
                    'amount': -e.amount,
                    'date': e.date,
                    'title': '${e.remarks} (via Wallet)',
                    'color': Colors.grey,
                    'item': e,
                    'budgetType': 'WALLET',
                    'status': 'Paid from Wallet',
                    'statusColor': Colors.grey,
                    'categoryPath': 'Charge to $actualBType: $catName',
                  });
                }

                return multi;
            }),

          ...provider.donations.where((d) => d.amount != 0).expand((d) {
                String? bType;
                String catName = 'General Wallet';
                if (d.mode == DonationMode.MERGE_TO_BUDGET && d.budgetCategoryId != null) {
                  try {
                    final cat = provider.categories.firstWhere((c) => c.id == d.budgetCategoryId);
                    bType = cat.budgetType.toString().split('.').last;
                    catName = '${cat.category} -> ${cat.subCategory}';
                  } catch (_) {}
                } else if (d.mode == DonationMode.WALLET) {
                  bType = 'WALLET';
                }

                final List<Map<String, dynamic>> multi = [];

                // 1. Budget Side
                multi.add({
                  'type': 'Donation',
                  'source': d.mode == DonationMode.WALLET ? 'WALLET' : 'ISKCON',
                  'amount': d.amount,
                  'date': d.date,
                  'title': d.remarks,
                  'color': Colors.greenAccent,
                  'item': d,
                  'budgetType': bType,
                  'status': 'Received',
                  'statusColor': Colors.greenAccent,
                  'categoryPath': catName,
                });

                // 2. Wallet Side (if earmarked donation was paid into wallet)
                if (d.mode == DonationMode.WALLET && bType != 'WALLET' && bType != null) {
                   multi.add({
                    'type': 'Wallet deposit',
                    'source': 'Wallet',
                    'amount': d.amount,
                    'date': d.date,
                    'title': '${d.remarks} (to Wallet)',
                    'color': Colors.grey,
                    'item': d,
                    'budgetType': 'WALLET',
                    'status': 'Wallet Credit',
                    'statusColor': Colors.grey,
                    'categoryPath': 'Earmarked for $bType',
                  });
                }

                return multi;
          }),
           ...provider.transfers.where((t) {
                final isDirect = t.costCenterId == activeCenter.id;
                final isSource = t.fromCategoryId != null && provider.categories.any((c) => c.id == t.fromCategoryId);
                final isDest = t.toCategoryId != null && provider.categories.any((c) => c.id == t.toCategoryId);
                return (isDirect || isSource || isDest) && t.amount != 0;
              }).expand((t) {
                if (t.type == TransferType.TO_PERSONAL) {
                  // Determine source budget type for the advance
                  String advBudgetType = 'WALLET';
                  String path = 'Wallet -> Personal';
                  if (t.fromCategoryId != null) {
                    try {
                      final cat = provider.categories.firstWhere((c) => c.id == t.fromCategoryId);
                      advBudgetType = cat.budgetType.toString().split('.').last;
                      path = '${cat.category} -> ${cat.subCategory}';
                    } catch (_) {
                       // Keep as Wallet if cat not found
                    }
                  }

                  return [{
                    'type': 'Transfer',
                    'source': 'Cost Center',
                    'amount': -t.amount,
                    'date': t.date,
                    'title': 'Advance: ${t.remarks}',
                    'color': Colors.blueAccent,
                    'item': t,
                    'budgetType': advBudgetType, 
                    'status': 'Advance',
                    'statusColor': Colors.blueAccent,
                    'categoryPath': path,
                  }];
                } else {
                   // Category-to-Category (or Category-to-Wallet)
                   final bool fromInCC = t.fromCategoryId != null && provider.categories.any((c) => c.id == t.fromCategoryId);
                   final bool toInCC = t.toCategoryId != null && provider.categories.any((c) => c.id == t.toCategoryId);

                   // HIDE pure internal category-to-category within SAME CC to reduce noise
                   if (fromInCC && toInCC) {
                      return <Map<String, dynamic>>[];
                   }

                   List<Map<String, dynamic>> entries = [];
                   
                   String? fromBType;
                   String fromName = 'Wallet/Unallocated';
                   if (t.fromCategoryId != null) {
                     try {
                       final cat = provider.categories.firstWhere((c) => c.id == t.fromCategoryId);
                       fromBType = cat.budgetType.toString().split('.').last;
                       fromName = '${cat.category} -> ${cat.subCategory}';
                     } catch (_) { fromBType = 'WALLET'; }
                   } else {
                     fromBType = 'WALLET';
                   }

                   String? toBType;
                   String toName = 'Wallet/Unallocated';
                   if (t.toCategoryId != null) {
                     try {
                       final cat = provider.categories.firstWhere((c) => c.id == t.toCategoryId);
                       toBType = cat.budgetType.toString().split('.').last;
                       toName = '${cat.category} -> ${cat.subCategory}';
                     } catch (_) { toBType = 'WALLET'; }
                   } else {
                     toBType = 'WALLET';
                   }

                   // If money COMES FROM our CC (Category or Wallet), add a Debit
                   if (fromInCC || (t.fromCategoryId == null && t.costCenterId == activeCenter.id)) {
                      entries.add({
                        'type': 'Internal Transfer',
                        'source': 'Outgoing',
                        'amount': -t.amount,
                        'date': t.date,
                        'title': 'Trf Out: ${t.remarks}',
                        'color': Colors.redAccent,
                        'item': t,
                        'budgetType': fromBType,
                        'status': 'Debited',
                        'statusColor': Colors.redAccent,
                        'categoryPath': 'From $fromName -> To $toName',
                      });
                   }

                   // If money GOES TO our CC (Category or Wallet), add a Credit
                   if (toInCC || (t.toCategoryId == null && t.costCenterId == activeCenter.id)) {
                      entries.add({
                        'type': 'Internal Transfer',
                        'source': 'Incoming',
                        'amount': t.amount,
                        'date': t.date,
                        'title': 'Trf In: ${t.remarks}',
                        'color': Colors.greenAccent,
                        'item': t,
                        'budgetType': toBType,
                        'status': 'Received',
                        'statusColor': Colors.greenAccent,
                        'categoryPath': 'From $fromName -> To $toName',
                      });
                   }

                   return entries;
                }
            }),
            ...provider.centerAdjustments.where((a) => a.amount != 0).map((a) {
                 final isCredit = a.type == AdjustmentType.CREDIT;
                 String? bType;
                 if (a.budgetType != null) {
                   bType = a.budgetType.toString().split('.').last;
                 } else {
                   bType = 'WALLET';
                 }
                 return {
                     'type': 'Adjustment',
                     'source': 'Center',
                     'amount': isCredit ? a.amount : -a.amount,
                     'date': a.date,
                     'title': a.remarks,
                     'color': Colors.orangeAccent,
                     'item': a,
                     'budgetType': bType,
                     'status': isCredit ? 'Credit' : 'Debit',
                     'statusColor': Colors.orangeAccent,
                     'categoryPath': 'Manual Adjustment',
                 };
            }),
            ...provider.allExpenses.where((e) => e.costCenterId == activeCenter.id && e.moneySource == MoneySource.PERSONAL && e.amount != 0 && e.isSettled).map((e) {
                 String catName = 'Global/Wallet';
                 String bType = 'WALLET';
                 try {
                   final cat = provider.categories.firstWhere((c) => c.id == e.categoryId);
                   catName = '${cat.category} -> ${cat.subCategory}';
                   bType = cat.budgetType.toString().split('.').last;
                 } catch (_) {}

                 return {
                   'type': 'Expense',
                   'source': 'Personal (Settled)',
                   'amount': -e.amount, 
                   'date': e.date,
                   'title': '${e.remarks} (${e.settledAgainstAdvance ? "Against Adv" : "Reimbursed"})',
                   'color': Colors.redAccent,
                   'item': e,
                   'budgetType': bType,
                   'status': 'Spent',
                   'statusColor': Colors.redAccent,
                   'categoryPath': catName,
                   'settledAgainstAdvance': e.settledAgainstAdvance, 
                 };
            }),
        ];

        // Header and Data Filtering
        double displayBalance = 0;
        String headerTitle = 'Cost Center Balance';

        if (filterMode == 'OTE') {
          displayBalance = provider.oteBalance;
          headerTitle = 'OTE Balance';
          allEntries = allEntries.where((e) => e['budgetType'] == 'OTE').toList();
        } else if (filterMode == 'PME') {
          displayBalance = provider.pmeBalance;
          headerTitle = 'PME Balance';
          allEntries = allEntries.where((e) => e['budgetType'] == 'PME' || (e['type'] == 'Transfer' && e['budgetType'] == 'PME')).toList();
        } else if (filterMode == 'WALLET') {
          displayBalance = provider.walletBalance;
          headerTitle = 'Wallet Balance';
          allEntries = allEntries.where((e) => e['budgetType'] == 'WALLET').toList();
        } else if (filterMode == 'ADVANCE') {
          displayBalance = provider.advanceUnsettled;
          headerTitle = 'Advance Unsettled';
          // ADVANCE view shows gross transitions + categorization of those advances
          allEntries = allEntries.where((e) => e['type'] == 'Transfer' || (e['type'] == 'Expense' && e['settledAgainstAdvance'] == true)).toList();
        } else {
           // ALL_CENTER (Total Bank Cash Health)
           displayBalance = provider.costCenterBudgetBalance;
           headerTitle = 'Total CC Balance';
           // ALL_CENTER shows everything that is a REAL BANK HIT.
           // Settled personal expenses ONLY hit the bank if NOT against an advance (Reimbursements).
           allEntries = allEntries.where((e) {
             if (e['type'] == 'Wallet usage' || e['type'] == 'Wallet deposit' || e['type'] == 'Budget Move') return false;
             if (e['type'] == 'Expense' && e['source'] == 'Personal (Settled)' && e['settledAgainstAdvance'] == true) return false;
             return true;
           }).toList();
        }

        // Apply Search and Date Filters
        if (_searchQuery.isNotEmpty) {
          allEntries = allEntries.where((e) {
            final titleMatch = (e['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
            final catMatch = (e['categoryPath'] as String? ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
            return titleMatch || catMatch;
          }).toList();
        }

        if (_selectedDateRange != null) {
          allEntries = allEntries.where((e) {
            final date = e['date'] as DateTime;
            return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                   date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        // Sort by date descending
        allEntries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        // Assign stable unique keys for selection
        for (int i = 0; i < allEntries.length; i++) {
          final entry = allEntries[i];
          final item = entry['item'];
          final type = entry['type'];
          
          if (item != null && item.id != null) {
            // Include type to distinguish between related entries for the same item (e.g., Expense and Settlement)
            entry['uniqueKey'] = '${type}_${item.id}';
          } else {
            // For synthetic entries, use title and date (which we've ensured is stable where needed)
            entry['uniqueKey'] = 'syn_${type}_${entry['title']}_${(entry['date'] as DateTime).millisecondsSinceEpoch}';
          }
        }

        double selectedSum = allEntries
            .where((e) => _selectedLedgerIds.contains(e['uniqueKey']))
            .fold(0.0, (sum, e) => sum + (e['amount'] as double));

        return Scaffold(
          appBar: AppBar(
            title: Text('${activeCenter.name} Ledger (v1.1.3+27)'),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade200,
                child: Column(
                   children: [
                    Text(headerTitle, style: TextStyle(fontSize: 14, color: provider.isDarkMode ? null : Colors.black87)),
                    Text(
                      '₹${displayBalance.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: provider.isDarkMode ? Colors.amber : Colors.amber.shade800),
                    ),
                    if (_selectedLedgerIds.isNotEmpty) ...[
                      Divider(height: 24, color: provider.isDarkMode ? Colors.white24 : Colors.grey.shade400),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: _selectedLedgerIds.length == allEntries.length,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedLedgerIds.addAll(allEntries.map((e) => e['uniqueKey'] as String));
                                        } else {
                                          _selectedLedgerIds.clear();
                                        }
                                      });
                                    },
                                    activeColor: Colors.tealAccent,
                                  ),
                                  Text('Select All', style: TextStyle(fontSize: 14, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade700)),
                                ],
                              ),
                              Row(
                                children: [
                                  Text('Sum: ', style: TextStyle(fontSize: 14, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade700, fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${selectedSum.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade700),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.close, size: 18, color: provider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                                    onPressed: () => setState(() => _selectedLedgerIds.clear()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                    ],
                  ],
                ),
              ),
              // Search and Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search ledger...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: provider.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                        ),
                        style: TextStyle(fontSize: 14, color: provider.isDarkMode ? null : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDateRange: _selectedDateRange,
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDateRange = picked;
                          });
                        }
                      },
                      icon: Icon(
                        Icons.calendar_today, 
                        size: 20,
                        color: _selectedDateRange != null ? Colors.amberAccent : (provider.isDarkMode ? Colors.white : Colors.black54),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: _selectedDateRange != null ? Colors.amber.withOpacity(0.2) : (provider.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_selectedDateRange != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                          });
                        },
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: allEntries.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (context, index) => Divider(height: 1, color: provider.isDarkMode ? null : Colors.grey.shade300),
                  itemBuilder: (context, index) {
                    final entry = allEntries[index];
                    final date = entry['date'] as DateTime;
                    final isPositive = (entry['amount'] as double) > 0;
                    final title = entry['title'] as String;
                    final type = entry['type'] as String;
                    final source = entry['source'] as String;
                    final status = entry['status'] as String;
                    final statusColor = entry['statusColor'] as Color;
                    final color = entry['color'] as Color;
                    final item = entry['item'];

                    final String uniqueKey = entry['uniqueKey'];
                    final bool isSelected = _selectedLedgerIds.contains(uniqueKey);

                    return InkWell(
                        onTap: () => _showEntryDetails(context, item, type),
                        child: Container(
                          color: isSelected ? Colors.teal.withOpacity(0.1) : null,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Small checkbox as requested
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedLedgerIds.add(uniqueKey);
                                      } else {
                                        _selectedLedgerIds.remove(uniqueKey);
                                      }
                                    });
                                  },
                                  activeColor: Colors.tealAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Icon Circle
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(date),
                                      style: TextStyle(color: provider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: provider.isDarkMode ? null : Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.containsKey('categoryPath') ? entry['categoryPath'] : '$type • $source',
                                      style: TextStyle(color: provider.isDarkMode ? Colors.white60 : Colors.grey.shade700, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPositive ? "+" : "-"}₹${(entry['amount'] as double).abs().toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                  if (status.isNotEmpty && status != 'N/A')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Create New Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.payment, color: Colors.redAccent),
            title: const Text('Direct Spend (Expense)'),
            onTap: () { 
              Navigator.pop(context); 
              _showHistoryPopup(
                context, 
                'Direct Spend History', 
                null,
                (p) => p.expenses.where((e) => e.moneySource != MoneySource.PERSONAL).toList(),
                'Expense', 
                const AddExpenseScreen()
              ); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.volunteer_activism, color: Colors.greenAccent),
            title: const Text('Donation'),
            onTap: () { 
              Navigator.pop(context); 
              _showHistoryPopup(
                context, 
                'Donation History', 
                null,
                (p) => p.donations,
                'Donation', 
                const AddDonationScreen()
              ); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
            title: const Text('Internal Fund Transfer'),
            onTap: () { 
              Navigator.pop(context); 
              _showForm(context, const AddTransferScreen(initialType: TransferType.CATEGORY_TO_CATEGORY)); 
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _showHistoryPopup(BuildContext context, String title, List<dynamic>? items, List<dynamic> Function(AccountingProvider)? itemSelector, String type, Widget addScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: title,
          items: items,
          itemSelector: itemSelector,
          type: type,
          addScreen: addScreen,
          showEntryDetails: _showEntryDetails,
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context, dynamic item, String type) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);

    // Special handling for System Generated (Budget/Surplus) entries where item is null
    if (item == null) {
      // Find the entry in the current view to get its metadata
      // Since we don't have the entry object here directly in the original method signature,
      // we'll accept that 'type' might be 'Budget' or similar.
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$type Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('System Generated Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Divider(),
              SizedBox(height: 8),
              Text('This is a calculated surplus or savings value generated by the system based on your budget periods and allocations.', style: TextStyle(fontSize: 14)),
              SizedBox(height: 8),
              Text('It is read-only and cannot be edited manually.', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    String getCatName(String? id) {
      if (id == null) return 'General Wallet / Unallocated';
      try {
        final cat = provider.categories.firstWhere((c) => c.id == id);
        return '${cat.category} -> ${cat.subCategory}';
      } catch (_) {
        return 'Unknown Category';
      }
    }

    String? categoryLine;
    List<Widget> extraDetails = [];

    if (item is Expense) {
      categoryLine = getCatName(item.categoryId);
      extraDetails = [
        const SizedBox(height: 8),
        Text('Money Source: ${item.moneySource.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 4),
        Text('Budget Type: ${item.budgetType.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
      ];
    } else if (item is Donation) {
      categoryLine = getCatName(item.budgetCategoryId);
      extraDetails = [
        const SizedBox(height: 8),
        Text('Mode: ${item.mode.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
      ];
    } else if (item is FundTransfer) {
      if (item.type == TransferType.CATEGORY_TO_CATEGORY) {
        extraDetails = [
          const SizedBox(height: 8),
          const Text('TRANSFER PATH:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('FROM: ${getCatName(item.fromCategoryId)}', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
          const SizedBox(height: 4),
          Text('TO: ${getCatName(item.toCategoryId)}', style: const TextStyle(fontSize: 14)),
        ];
      } else {
        extraDetails = [
          const SizedBox(height: 8),
          const Text('TYPE: Personal Advance', style: TextStyle(fontSize: 14, color: Colors.blueAccent)),
        ];
      }
    }

    String? costCenterName;
    if (type != 'Adjustment' || item is CostCenterAdjustment) {
      try {
        final cc = provider.costCenters.where((c) => c.id == item.costCenterId).toList();
        if (cc.isNotEmpty) costCenterName = cc.first.name;
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type == 'Internal Transfer' ? 'Fund Transfer' : type} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks: ${item.remarks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            Text('Amount: ₹${item.amount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(item.date)}', style: const TextStyle(fontSize: 15)),
            if (categoryLine != null) ...[
              const SizedBox(height: 4),
              Text('Category: $categoryLine', style: const TextStyle(fontSize: 15)),
            ],
            if (costCenterName != null) ...[
              const SizedBox(height: 4),
              Text('Cost Center: $costCenterName', style: const TextStyle(fontSize: 15)),
            ],
            ...extraDetails,
            if (type == 'Adjustment') ...[
              const SizedBox(height: 8),
              Text('Adjustment Type: ${item.type.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'Expense') {
                _showForm(context, AddExpenseScreen(expenseToEdit: item as Expense));
              } else if (type == 'Donation') {
                _showForm(context, AddDonationScreen(donationToEdit: item as Donation));
              } else if (type == 'Adjustment') {
                if (item is PersonalAdjustment) {
                  _showForm(context, AddAdjustmentScreen(adjustmentToEdit: item));
                } else {
                  _showForm(context, AddCenterAdjustmentScreen(adjustmentToEdit: item as CostCenterAdjustment));
                }
              } else if (type == 'Transfer' || type == 'Internal Transfer') {
                _showForm(context, AddTransferScreen(transferToEdit: item as FundTransfer));
              }
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => _confirmDelete(context, item.id, type),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String entryId, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this $type?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final service = FirestoreService();
              if (type == 'Expense') await service.deleteExpense(entryId);
              else if (type == 'Donation') await service.deleteDonation(entryId);
              else if (type == 'Transfer' || type == 'Internal Transfer') await service.deleteFundTransfer(entryId);
              else if (type == 'Adjustment') {
                // Determine if it's a Personal or Cost Center adjustment by checking its properties 
                // but since Ledger mostly shows Cost Center adjustments:
                await service.deleteCostCenterAdjustment(entryId);
              }
              
              if (ctx.mounted) {
                Navigator.pop(ctx); // Close confirmation
              }
              if (context.mounted) {
                Navigator.pop(context); // Close details
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
