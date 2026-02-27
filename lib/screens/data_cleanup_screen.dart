import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/fund_transfer.dart';
import '../models/budget_category.dart';
import 'add_transfer_screen.dart';

class DataCleanupScreen extends StatelessWidget {
  const DataCleanupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Cleanup & Validation'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final issues = _identifyIssues(provider);
          
          if (issues.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'All Good!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('No negative balances or PME issues found.'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: issues.length,
            itemBuilder: (context, index) {
              final issue = issues[index];
              return Card(
                elevation: 0,
                color: issue.isCritical ? Colors.red.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: issue.isCritical ? Colors.red.shade200 : Colors.orange.shade200,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: Icon(
                    issue.isCritical ? Icons.error_outline : Icons.warning_amber_rounded,
                    color: issue.isCritical ? Colors.red : Colors.orange.shade700,
                  ),
                  title: Text(
                    issue.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(issue.description),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const Text(
                            'Related Transactions:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ...issue.relatedTransfers.map((t) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('₹${t.amount.toStringAsFixed(0)} - ${t.remarks}'),
                            subtitle: Text(DateFormat('dd MMM yyyy').format(t.date)),
                            trailing: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => AddTransferScreen(transferToEdit: t)),
                                );
                              },
                              child: const Text('Edit'),
                            ),
                          )),
                          if (issue.type == IssueType.negativeBalance)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => AddTransferScreen(
                                        initialType: TransferType.CATEGORY_TO_CATEGORY,
                                      )),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Fund to Refill'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<_ValidationIssue> _identifyIssues(AccountingProvider provider) {
    final List<_ValidationIssue> issues = [];

    // 1. Check for Negative Wallet
    if (provider.walletBalance < -1) {
      final walletTransfers = provider.transfers
          .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY)
          .where((t) => t.fromCategoryId == null || t.toCategoryId == null)
          .toList();

      issues.add(_ValidationIssue(
        title: 'Negative Wallet Balance',
        description: 'Your unallocated wallet is ₹${provider.walletBalance.toStringAsFixed(0)}. You have moved more money out than you have received.',
        isCritical: true,
        type: IssueType.negativeBalance,
        relatedTransfers: walletTransfers.take(5).toList(),
      ));
    }

    // 2. Check for Negative Categories
    for (var cat in provider.categories) {
      final status = provider.getCategoryStatus(cat);
      final remaining = status['remaining'] ?? 0;
      if (remaining < -1) {
        final related = provider.transfers
            .where((t) => t.fromCategoryId == cat.id || t.toCategoryId == cat.id)
            .toList();

        issues.add(_ValidationIssue(
          title: 'Negative Balance: ${cat.category} > ${cat.subCategory}',
          description: 'This category is over-spent or over-transferred by ₹${remaining.abs().toStringAsFixed(0)}.',
          isCritical: true,
          type: IssueType.negativeBalance,
          relatedTransfers: related.take(5).toList(),
        ));
      }
    }

    // 3. Check for PME Transfers without Months
    final pmeCats = provider.categories.where((c) => c.budgetType == BudgetType.PME).map((c) => c.id).toSet();
    final missingMonthPme = provider.transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY)
        .where((t) => t.targetMonth == null)
        .where((t) => (t.fromCategoryId != null && pmeCats.contains(t.fromCategoryId)) || 
                      (t.toCategoryId != null && pmeCats.contains(t.toCategoryId)))
        .toList();

    if (missingMonthPme.isNotEmpty) {
      issues.add(_ValidationIssue(
        title: 'PME Transfers Missing Month',
        description: '${missingMonthPme.length} PME transfers don\'t have a target month. They won\'t show up in monthly reports.',
        isCritical: false,
        type: IssueType.missingPmeMonth,
        relatedTransfers: missingMonthPme,
      ));
    }

    return issues;
  }
}

enum IssueType { negativeBalance, missingPmeMonth }

class _ValidationIssue {
  final String title;
  final String description;
  final bool isCritical;
  final IssueType type;
  final List<FundTransfer> relatedTransfers;

  _ValidationIssue({
    required this.title,
    required this.description,
    required this.isCritical,
    required this.type,
    required this.relatedTransfers,
  });
}
