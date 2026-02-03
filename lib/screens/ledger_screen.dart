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
import '../models/cost_center_adjustment.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

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

        // Calculate unallocated amounts for Wallet view
        double totalOteAllocated = provider.categories.where((c) => c.budgetType == BudgetType.OTE).fold(0, (sum, c) => sum + c.targetAmount);
        double totalPmeAllocated = provider.categories.where((c) => c.budgetType == BudgetType.PME).fold(0, (sum, c) => sum + c.targetAmount);

        // Synthetic Budget Entries
        List<Map<String, dynamic>> budgetEntries = [];
        
        if (activeCenter != null) {
             DateTime pmeStart;
             try {
                pmeStart = DateFormat('yyyy-MM').parse(activeCenter.pmeStartMonth);
             } catch (_) {
                pmeStart = DateTime(2026, 1);
             }

             // OTE Allocation
             double oteAmount = activeCenter.defaultOteAmount;
             if (filterMode == 'WALLET') {
                oteAmount -= totalOteAllocated;
             }
             
              // Only show Budget entry in OTE, ALL_CENTER or Wallet view
              if ((filterMode == 'OTE' || filterMode == 'ALL_CENTER' || filterMode == 'WALLET') && oteAmount != 0) {
                  budgetEntries.add({
                      'type': 'Budget',
                      'source': 'System',
                      'amount': oteAmount,
                      'date': pmeStart,
                      'title': filterMode == 'WALLET' ? 'OTE Wallet Fund' : 'OTE Budget Allocation',
                      'color': Colors.tealAccent,
                      'item': null,
                      'budgetType': 'OTE',
                      'status': 'Allocated',
                      'statusColor': Colors.teal,
                  });
              }

             // PME Monthly Allocations
             DateTime now = DateTime.now();
             DateTime current = pmeStart;
             double pmeAmount = activeCenter.defaultPmeAmount;
             if (filterMode == 'WALLET') {
                pmeAmount -= totalPmeAllocated;
             }

             // Show PME Allocations in ALL_CENTER, PME view or Wallet view
             if ((filterMode == 'ALL_CENTER' || filterMode == 'PME' || filterMode == 'WALLET') && pmeAmount != 0) {
                 while (current.isBefore(now) || (current.month == now.month && current.year == now.year)) {
                      budgetEntries.add({
                         'type': 'Budget',
                         'source': 'System',
                         'amount': pmeAmount,
                         'date': current,
                         'title': filterMode == 'WALLET' ? 'Monthly Wallet Fund' : 'Monthly PME Budget',
                         'color': Colors.purpleAccent,
                         'item': null,
                         'budgetType': 'PME',
                         'status': 'Recurring',
                         'statusColor': Colors.purple,
                      });
                      current = DateTime(current.year, current.month + 1, 1);
                 }
             }
        }

        // Gather all relevant transactions for this center
        List<Map<String, dynamic>> allEntries = [
          ...budgetEntries,
          ...provider.expenses.where((e) => e.moneySource != MoneySource.PERSONAL).map((e) => {
                'type': 'Expense',
                'source': e.moneySource.toString().split('.').last,
                'amount': -e.amount,
                'date': e.date,
                'title': e.remarks,
                'color': Colors.redAccent,
                'item': e,
                'budgetType': e.budgetType.toString().split('.').last,
                'status': 'Debited',
                'statusColor': Colors.redAccent,
              }),

          ...provider.donations.map((d) {
                String bType = 'OTE';
                try {
                   bType = provider.categories.firstWhere((c) => c.id == d.budgetCategoryId).budgetType.toString().split('.').last;
                } catch (_) {}
                return {
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
              };
          }),
           ...provider.transfers.where((t) => t.costCenterId == activeCenter.id).map((t) => {
                'type': 'Transfer',
                'source': 'Cost Center',
                'amount': -t.amount,
                'date': t.date,
                'title': 'Advance: ${t.remarks}',
                'color': Colors.blueAccent,
                'item': t,
                'budgetType': 'PME', // Transfers usually impact PME room
                'status': 'Advance',
                'statusColor': Colors.blueAccent,
           }),
           ...provider.centerAdjustments.map((a) {
                final isCredit = a.type == AdjustmentType.CREDIT;
                return {
                    'type': 'Adjustment',
                    'source': 'Center',
                    'amount': isCredit ? a.amount : -a.amount,
                    'date': a.date,
                    'title': a.remarks,
                    'color': Colors.orangeAccent,
                    'item': a,
                    'budgetType': a.budgetType.toString().split('.').last,
                    'status': isCredit ? 'Credit' : 'Debit',
                    'statusColor': Colors.orangeAccent,
                };
           }),
           // Personal Expenses (for Advance view)
           ...provider.expenses.where((e) => e.moneySource == MoneySource.PERSONAL).map((e) {
                return {
                    'type': 'Settlement',
                    'source': 'Personal',
                    'amount': e.amount, // Positive because it reduces the "Advance Taken" debt
                    'date': e.date,
                    'title': 'Settled: ${e.remarks}',
                    'color': e.isSettled ? Colors.green : Colors.grey,
                    'item': e,
                    'budgetType': e.budgetType.toString().split('.').last,
                    'status': e.isSettled ? 'Settled' : 'Unsettled',
                    'statusColor': e.isSettled ? Colors.green : Colors.grey,
                };
           }),
        ];

        // Header and Data Filtering
        double displayBalance = 0;
        String headerTitle = 'Cost Center Balance';

        if (filterMode == 'OTE') {
          displayBalance = provider.oteBalance;
          headerTitle = 'OTE Balance';
          allEntries = allEntries.where((e) => e['budgetType'] == 'OTE' && e['type'] != 'Transfer' && e['type'] != 'Settlement').toList();
        } else if (filterMode == 'PME') {
          displayBalance = provider.pmeBalance;
          headerTitle = 'PME Balance';
          allEntries = allEntries.where((e) => e['budgetType'] == 'PME' && e['type'] != 'Transfer' && e['type'] != 'Settlement').toList();
        } else if (filterMode == 'WALLET') {
          displayBalance = provider.walletBalance;
          headerTitle = 'Wallet Balance';
          allEntries = allEntries.where((e) {
            final type = e['type'];
            final source = e['source'];
            final item = e['item'];
            
            return source == 'WALLET' || 
                   type == 'Budget' || 
                   (type == 'Adjustment' && item is CostCenterAdjustment && item.categoryId == null);
          }).toList();
        } else if (filterMode == 'ADVANCE') {
          displayBalance = provider.advanceUnsettled;
          headerTitle = 'Advance Unsettled';
          allEntries = allEntries.where((e) => e['type'] == 'Transfer' || e['type'] == 'Settlement').toList();
        } else {
           // ALL_CENTER
           displayBalance = provider.costCenterBudgetBalance;
           headerTitle = 'Total CC Balance';
           // ALL_CENTER should show all entries except personal expenses (settlements)
           allEntries = allEntries.where((e) => e['type'] != 'Settlement').toList();
        }

        // Sort by date descending
        allEntries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        return Scaffold(
          appBar: AppBar(
            title: Text('${activeCenter.name} Ledger'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddMenu(context),
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.white10,
                child: Column(
                   children: [
                    Text(headerTitle, style: const TextStyle(fontSize: 14)),
                    Text(
                      '₹${displayBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Center Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.6,
                children: [
                   _ActionCard(
                    icon: Icons.payment,
                    color: Colors.redAccent,
                    label: 'Spend',
                    onTap: () {
                       _showHistoryPopup(context, 'Direct Spend History', provider.expenses.where((e) => e.moneySource != MoneySource.PERSONAL).toList(), 'Expense', const AddExpenseScreen());
                    },
                  ),
                  _ActionCard(
                    icon: Icons.volunteer_activism,
                    color: Colors.greenAccent,
                    label: 'Donation',
                    onTap: () => _showHistoryPopup(context, 'Donation History', provider.donations, 'Donation', const AddDonationScreen()),
                  ),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: allEntries.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (context, index) => const Divider(height: 1),
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

                    return InkWell(
                        onTap: () => _showEntryDetails(context, item, type),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withOpacity(0.1),
                                radius: 20,
                                child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('dd MMM').format(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(height: 2),
                                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('$type • $source', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPositive ? '+' : ''}₹${(entry['amount'] as double).abs().toStringAsFixed(0)}',
                                    style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
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
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_note, size: 22, color: Colors.blueAccent),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () {
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
                                  } else if (type == 'Transfer') {
                                    _showForm(context, AddTransferScreen(transferToEdit: item as FundTransfer));
                                  }
                                },
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
              final provider = Provider.of<AccountingProvider>(context, listen: false);
              Navigator.pop(context); 
              _showHistoryPopup(context, 'Direct Spend History', provider.expenses.where((e) => e.moneySource != MoneySource.PERSONAL).toList(), 'Expense', const AddExpenseScreen()); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.volunteer_activism, color: Colors.greenAccent),
            title: const Text('Donation'),
            onTap: () { 
              final provider = Provider.of<AccountingProvider>(context, listen: false);
              Navigator.pop(context); 
              _showHistoryPopup(context, 'Donation History', provider.donations, 'Donation', const AddDonationScreen()); 
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, Widget screen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: screen,
      ),
    );
  }

  void _showEntryDetails(BuildContext context, dynamic item, String type) {
    if (item == null) return; // For system generated entries like Budget
    final provider = Provider.of<AccountingProvider>(context, listen: false);

    String? categoryName;
    if (item is Expense) {
      final cat = provider.categories.where((c) => c.id == item.categoryId).toList();
      if (cat.isNotEmpty) categoryName = cat.first.name;
    } else if (item is Donation) {
      final cat = provider.categories.where((c) => c.id == item.budgetCategoryId).toList();
      if (cat.isNotEmpty) categoryName = cat.first.name;
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
        title: Text('$type Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks: ${item.remarks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            Text('Amount: ₹${item.amount}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(item.date)}', style: const TextStyle(fontSize: 15)),
            if (categoryName != null) ...[
              const SizedBox(height: 4),
              Text('Category: $categoryName', style: const TextStyle(fontSize: 15)),
            ],
            if (costCenterName != null) ...[
              const SizedBox(height: 4),
              Text('Cost Center: $costCenterName', style: const TextStyle(fontSize: 15)),
            ],
            if (type == 'Expense') ...[
              const SizedBox(height: 8),
              Text('Source: ${item.moneySource.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text('Budget: ${item.budgetType.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
            ],
            if (type == 'Adjustment') ...[
              const SizedBox(height: 8),
              Text('Type: ${item.type.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
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
              } else if (type == 'Transfer') {
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
              else if (type == 'Transfer') await service.deleteFundTransfer(entryId);
              else if (type == 'Adjustment') await service.deleteCostCenterAdjustment(entryId);
              
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
  void _showHistoryPopup(BuildContext context, String title, List<dynamic> items, String type, Widget addScreen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.tealAccent, size: 28),
                      onPressed: () {
                        Navigator.pop(context);
                        _showForm(context, addScreen);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No entries found.'))
                    : () {
                        final sortedItems = List.from(items)..sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));
                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: sortedItems.length,
                          itemBuilder: (context, index) {
                            final item = sortedItems[index];
                            return ListTile(
                            title: Text(item.remarks),
                            subtitle: Text(DateFormat('MMM dd, yyyy').format(item.date)),
                            trailing: Text(
                              '₹${item.amount}', 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _showEntryDetails(context, item, type == 'PersonalAdjustment' ? 'Adjustment' : type);
                            },
                          );
                        },
                      );
                    }(),
              ),
            ],
          ),
        );
      },
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
