import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/budget_category.dart';
import '../models/cost_center_adjustment.dart';
import '../models/fund_transfer.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../models/donation.dart';
import 'add_expense_screen.dart';
import 'add_donation_screen.dart';
import 'add_transfer_screen.dart';
import 'add_center_adjustment_screen.dart';
import 'add_adjustment_screen.dart';
import 'transaction_history_screen.dart';
import '../models/personal_adjustment.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final oteCats = provider.categories.where((c) => c.budgetType == BudgetType.OTE).toList();
    final pmeCats = provider.categories.where((c) => c.budgetType == BudgetType.PME).toList();

    return Scaffold(
      backgroundColor: provider.isDarkMode ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Budget Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: provider.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade200),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.teal.shade400,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'OTE (One-Time)'),
                  Tab(text: 'PME (Recurring)'),
                ],
              ),
            ),
            Expanded(
              child: provider.categories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_tree_outlined, size: 80, color: Colors.teal.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('No categories created yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text('Start by adding a category below', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : TabBarView(
                      children: [
                        _buildCategoryList(context, provider, oteCats, BudgetType.OTE),
                        _buildCategoryList(context, provider, pmeCats, BudgetType.PME),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal.shade400,
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, AccountingProvider provider, List<BudgetCategory> items, BudgetType type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No ${type.name} categories found', style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Category'),
            )
          ],
        ),
      );
    }

    // Unified summary calculations for the whole Project
    double totalBudget = 0;
    double totalSpent = 0;
    double totalWalletSurplus = 0;

    for (var cat in provider.categories) {
      if (!cat.isActive) continue;
      final status = provider.getCategoryStatus(cat);
      totalBudget += status['total_limit'] ?? 0;
      totalSpent += status['spent'] ?? 0;

      final outgoingToWallet = provider.transfers
          .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId == cat.id && t.toCategoryId == null)
          .fold(0.0, (sum, t) => sum + t.amount);

      final incomingFromWallet = provider.transfers
          .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId == cat.id && t.fromCategoryId == null)
          .fold(0.0, (sum, t) => sum + t.amount);

      // Only count surplus logic for the categories that would be in this tab for the surplus row?
      // No, let's just make the whole header Project-level data.
      totalWalletSurplus += (outgoingToWallet - incomingFromWallet);
    }

    final unallocatedSection = provider.walletBalance; 

    // grouping
    final Map<String, List<BudgetCategory>> grouped = {};
    for (var item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return CustomScrollView(
      slivers: [
        // --- Dashboard Header Section ---
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: provider.isDarkMode 
                  ? [Colors.teal.shade900, Colors.black] 
                  : [Colors.teal.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROJECT BUDGET DASHBOARD'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.5,
                    color: Colors.teal.shade400
                  ),
                ),
                const SizedBox(height: 20),
                
                // Primary Metric Row: Limit and Spent
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context, 
                        'Project Limit', 
                        '₹${totalBudget.toStringAsFixed(0)}', 
                        Icons.account_balance_wallet, 
                        Colors.blue,
                        subtitle: 'PME + OTE Categories',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context, 
                        'Total Spent', 
                        '₹${totalSpent.toStringAsFixed(0)}', 
                        Icons.shopping_cart, 
                        Colors.orange,
                        percentage: totalBudget > 0 ? (totalSpent / totalBudget) : 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Secondary Metric Row: Remaining and Unallocated
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        context, 
                        'Pending Pool', 
                        '₹${(totalBudget - totalSpent).toStringAsFixed(0)}', 
                        Icons.hourglass_empty, 
                        Colors.green,
                        subtitle: 'Funds remaining',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        context, 
                        'Unallocated', 
                        '₹${unallocatedSection.toStringAsFixed(0)}', 
                        Icons.add_to_photos, 
                        Colors.purple,
                        subtitle: 'Available to distribute',
                      ),
                    ),
                  ],
                ),
                
                if (totalWalletSurplus.abs() > 0) ...[
                  const SizedBox(height: 8),
                  _buildSlimMetricRow(
                    context, 
                    totalWalletSurplus < 0 ? 'Contribution from Wallet' : 'Contribution to Wallet', 
                    '₹${totalWalletSurplus.abs().toStringAsFixed(0)}',
                    totalWalletSurplus < 0 ? Colors.green : Colors.orange,
                  ),
                ],
              ],
            ),
          ),
        ),

        // --- Category Groups ---
        ...sortedKeys.map((mainCategory) {
          final subItems = grouped[mainCategory]!;
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        mainCategory,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${subItems.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildExpandableCategoryCard(context, provider, subItems[index]),
                    childCount: subItems.length,
                  ),
                ),
              ),
            ],
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color, {double? percentage, String? subtitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              if (percentage != null)
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle, style: TextStyle(fontSize: 9, color: color.withOpacity(0.8), fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _buildSlimMetricRow(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildExpandableCategoryCard(BuildContext context, AccountingProvider provider, BudgetCategory cat) {
    final status = provider.getCategoryStatus(cat);
    final double spent = status['spent']!;
    final double totalLimit = status['total_limit']!;
    final double progress = totalLimit > 0 ? (spent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final bool isOver = spent > totalLimit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            cat.subCategory,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cat.remarks.isNotEmpty)
                Text(cat.remarks, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red : Colors.teal),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '₹${(totalLimit - spent).abs().toStringAsFixed(0)} ${(totalLimit - spent) < 0 ? 'Over' : 'Left'}',
                    style: TextStyle(
                      fontSize: 11, 
                      fontWeight: FontWeight.bold,
                      color: (totalLimit - spent) < 0 ? Colors.red : Colors.green
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${spent.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('of ₹${totalLimit.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          children: [
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Action Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildActionItem(context, 'Withdraw', Icons.arrow_upward, Colors.orange, () => _showTransferDialog(context, cat, true)),
                      _buildActionItem(context, 'Top Up', Icons.arrow_downward, Colors.green, () => _showTransferDialog(context, cat, false)),
                      _buildActionItem(context, 'History', Icons.history, Colors.blue, () => _showTransactions(context, cat)),
                      _buildActionItem(context, 'More', Icons.more_horiz, Colors.grey, () => _showMoreActions(context, cat)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Detailed Stats
                  _buildDetailRow('Base Budget', '₹${status['budget']?.toStringAsFixed(0)}'),
                  _buildDetailRow('Donations', '₹${status['donations']?.toStringAsFixed(0)}', color: Colors.green),
                  _buildDetailRow('Adjustments', '₹${status['adjustments']?.toStringAsFixed(0)}', color: Colors.blue),
                  _buildDetailRow('Transfers (Net)', '₹${status['transfers']?.toStringAsFixed(0)}', color: Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showMoreActions(BuildContext context, BudgetCategory cat) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(cat.subCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Category'),
              onTap: () { Navigator.pop(context); _showEditDialog(context, cat); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.teal),
              title: const Text('Duplicate / template'),
              onTap: () { Navigator.pop(context); _showAddDialog(context, template: cat); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Category', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _showDeleteConfirm(context, cat); },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }



  void _showTransferDialog(BuildContext context, BudgetCategory cat, bool isToWallet) {
    final amountController = TextEditingController();
    final remarksController = TextEditingController();

    // Default amount: remaining for "To Wallet", 0 for "From Wallet"
    // For "To Wallet", we probably want to move EVERYTHING remaining by default
    if (isToWallet) {
       final provider = Provider.of<AccountingProvider>(context, listen: false);
       final status = provider.getCategoryStatus(cat);
       final remaining = status['remaining'] ?? 0.0;
       if (remaining > 0) {
         amountController.text = remaining.toStringAsFixed(0);
       }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isToWallet ? 'Move to Wallet' : 'Add from Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Processing for: ${cat.subCategory}'),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(labelText: 'Remarks (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount <= 0) return;

              final provider = Provider.of<AccountingProvider>(context, listen: false);
              
              await provider.transferBetweenCategoryAndWallet(
                categoryId: cat.id,
                amount: amount,
                isToWallet: isToWallet,
                remarks: remarksController.text,
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer Successful!')));
              }
            },
            child: const Text('Transfer'),
          )
        ],
      ),
    );
  }

  void _showTransactions(BuildContext context, BudgetCategory cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: '${cat.subCategory} History',
          type: 'CategoryHistory', 
          addScreen: const AddExpenseScreen(), 
          contextEntityId: cat.id,
          itemSelector: (provider) {
            // 1. Expenses
            final catExpenses = provider.expenses
                .where((e) => e.categoryId == cat.id && (e.moneySource != MoneySource.PERSONAL || e.isSettled))
                .toList();

            // 2. Donations (Merged to this category)
            final catDonations = provider.donations
                .where((d) => d.mode == DonationMode.MERGE_TO_BUDGET && d.budgetCategoryId == cat.id)
                .toList();

            // 3. Adjustments
            final catAdjustments = provider.centerAdjustments
                .where((a) => a.categoryId == cat.id)
                .toList();

            // 4. Transfers (In/Out)
            final catTransfers = provider.transfers.where((t) {
              return t.type == TransferType.CATEGORY_TO_CATEGORY && 
                     (t.fromCategoryId == cat.id || t.toCategoryId == cat.id);
            }).toList();

            final List<dynamic> allHistory = [
              ...catExpenses,
              ...catDonations,
              ...catAdjustments,
              ...catTransfers,
            ];

            // 5. Budget Allotments
            if (cat.budgetType == BudgetType.PME) {
              final Set<String> elapsedMonths = {};
              for (var period in provider.budgetPeriods.where((p) => p.isActive)) {
                for (var month in period.getAllMonths()) {
                  if (provider.isMonthInPastOrCurrent(month)) {
                    elapsedMonths.add(month);
                  }
                }
              }
              for (var m in elapsedMonths) {
                DateTime allotmentDate;
                String displayMonth = m;
                try {
                  allotmentDate = DateFormat('yyyy-MM').parse(m);
                  displayMonth = DateFormat('MMM yyyy').format(allotmentDate);
                } catch(_) { allotmentDate = DateTime.now(); }

                allHistory.add(BudgetCategory(
                  id: '${cat.id}_$m', 
                  costCenterId: cat.costCenterId,
                  category: cat.category,
                  subCategory: 'Monthly Budget: $displayMonth',
                  budgetType: BudgetType.PME,
                  targetAmount: cat.targetAmount,
                  isActive: true,
                  remarks: 'Budget Allotment for $displayMonth',
                  createdAt: allotmentDate,
                ));
              }
            } else if (cat.targetAmount > 0) {
              allHistory.add(cat);
            }
            return allHistory;
          },
          showEntryDetails: (context, item, type) => _showEntryDetails(context, item),
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context, dynamic item) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);

    String getCatName(String? id) {
      if (id == null) return 'General Wallet / Unallocated';
      try {
        final cat = provider.categories.firstWhere((c) => c.id == id);
        return '${cat.category} -> ${cat.subCategory}';
      } catch (_) {
        return 'Unknown Category';
      }
    }

    String type = 'Transaction';
    if (item is Expense) type = 'Expense';
    else if (item is Donation) type = 'Donation';
    else if (item is FundTransfer) type = item.type == TransferType.CATEGORY_TO_CATEGORY ? 'Internal Transfer' : 'Transfer';
    else if (item is CostCenterAdjustment) type = 'Adjustment';
    else if (item is BudgetCategory) {
       // Synthetic entry, just show details
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text('Budget Allotment'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Remarks: ${item.remarks}', style: const TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Text('Amount: ₹${item.targetAmount.toStringAsFixed(0)}'),
             ],
           ),
           actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
         ),
       );
       return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks: ${item.remarks ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            Text('Amount: ₹${item.amount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(item.date ?? DateTime.now())}'),
            if (item is FundTransfer && item.type == TransferType.CATEGORY_TO_CATEGORY) ...[
               const SizedBox(height: 8),
               Text('FROM: ${getCatName(item.fromCategoryId)}', style: const TextStyle(fontSize: 13)),
               Text('TO: ${getCatName(item.toCategoryId)}', style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (item is Expense) Navigator.push(context, MaterialPageRoute(builder: (c) => AddExpenseScreen(expenseToEdit: item)));
              else if (item is Donation) Navigator.push(context, MaterialPageRoute(builder: (c) => AddDonationScreen(donationToEdit: item)));
              else if (item is FundTransfer) Navigator.push(context, MaterialPageRoute(builder: (c) => AddTransferScreen(transferToEdit: item)));
              else if (item is CostCenterAdjustment) Navigator.push(context, MaterialPageRoute(builder: (c) => AddCenterAdjustmentScreen(adjustmentToEdit: item)));
            },
            child: const Text('Edit'),
          ),

          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmTransactionDelete(context, item, type);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmTransactionDelete(BuildContext context, dynamic item, String type) {
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
              if (item is Expense) await service.deleteExpense(item.id);
              else if (item is Donation) await service.deleteDonation(item.id);
              else if (item is FundTransfer) await service.deleteFundTransfer(item.id);
              else if (item is CostCenterAdjustment) await service.deleteCostCenterAdjustment(item.id);
              
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, BudgetCategory cat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${cat.category} - ${cat.subCategory}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteCategory(cat.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Category deleted successfully!')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, BudgetCategory cat) {
    final categoryController = TextEditingController(text: cat.category);
    final subCategoryController = TextEditingController(text: cat.subCategory);
    final amountController = TextEditingController(text: cat.targetAmount.toString());
    final remarksController = TextEditingController(text: cat.remarks);
    BudgetType budgetType = cat.budgetType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category Name (e.g. Travel)')),
                    TextField(controller: subCategoryController, decoration: const InputDecoration(labelText: 'Sub Category (Item)')),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Allotted Budget (₹)'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<BudgetType>(
                      value: budgetType,
                      items: BudgetType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                      onChanged: (val) => setState(() => budgetType = val!),
                      decoration: const InputDecoration(labelText: 'Budget Type'),
                    ),
                    TextField(controller: remarksController, decoration: const InputDecoration(labelText: 'Remarks')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final newAmount = double.tryParse(amountController.text) ?? 0.0;
                    
                    // Validation: Check if this update exceeds strict budget limits
                    // We need to temporarily simulate the change
                    // "Allocation" check: (Total Allocations - Old Amount + New Amount) <= Total Available
                    
                    final provider = Provider.of<AccountingProvider>(context, listen: false);
                    final otherCategories = provider.categories.where((c) => c.id != cat.id && c.budgetType == budgetType);
                    double totalAllocated = otherCategories.fold(0.0, (sum, c) => sum + c.targetAmount);
                    totalAllocated += newAmount;

                    double limits = 0;
                    if (budgetType == BudgetType.PME) {
                      // Sum of monthly PME from active periods
                      limits = provider.budgetPeriods.where((p) => p.isActive).fold(0, (sum, p) => sum + p.defaultPmeAmount);
                    } else {
                      // Sum of OTE from active periods
                      limits = provider.budgetPeriods.where((p) => p.isActive).fold(0, (sum, p) => sum + p.oteAmount);
                    }

                    if (totalAllocated > limits) {
                      // Strict Rule: Block update
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Strict Rule: Total ${budgetType.name} allocation (₹$totalAllocated) exceeds available budget (₹$limits)!'),
                          backgroundColor: Colors.red,
                        )
                      );
                      return; 
                    }

                    final updated = BudgetCategory(
                      id: cat.id,
                      costCenterId: cat.costCenterId,
                      category: categoryController.text,
                      subCategory: subCategoryController.text,
                      budgetType: budgetType,
                      targetAmount: newAmount,
                      isActive: cat.isActive,
                      remarks: remarksController.text,
                      createdAt: cat.createdAt,
                    );
                    await FirestoreService().updateCategory(updated);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category updated successfully!')),
                      );
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, {BudgetCategory? template}) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final categoryController = TextEditingController(text: template?.category ?? '');
    final subCategoryController = TextEditingController(text: template?.subCategory ?? '');
    final amountController = TextEditingController(text: template?.targetAmount.toString() ?? '0');
    final remarksController = TextEditingController(text: template?.remarks ?? '');
    BudgetType budgetType = template?.budgetType ?? BudgetType.OTE;

    if (provider.activeCostCenterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active cost center selected.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(template != null ? 'Duplicate Category' : 'Add Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: categoryController, 
                      decoration: const InputDecoration(labelText: 'Category (e.g. Travel)', hintText: 'Travel, Food, Assets...'),
                    ),
                    TextField(
                      controller: subCategoryController, 
                      decoration: const InputDecoration(labelText: 'Sub Category (Item)', hintText: 'Mridangam, Repairs, Lunch...'),
                    ),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(labelText: 'Monthly Allotted Budget (₹)'),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<BudgetType>(
                      value: budgetType,
                      items: BudgetType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                      onChanged: (val) => setState(() => budgetType = val!),
                      decoration: const InputDecoration(labelText: 'Budget Type'),
                    ),
                    TextField(controller: remarksController, decoration: const InputDecoration(labelText: 'Remarks')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (categoryController.text.isEmpty) return;
                    
                    final newAmount = double.tryParse(amountController.text) ?? 0.0;
                    
                    // Validation for Strict Rules
                    final otherCategories = provider.categories.where((c) => c.budgetType == budgetType);
                    double totalAllocated = otherCategories.fold(0.0, (sum, c) => sum + c.targetAmount);
                    totalAllocated += newAmount;

                    double limits = 0;
                    if (budgetType == BudgetType.PME) {
                      limits = provider.budgetPeriods.where((p) => p.isActive).fold(0, (sum, p) => sum + p.defaultPmeAmount);
                    } else {
                      limits = provider.budgetPeriods.where((p) => p.isActive).fold(0, (sum, p) => sum + p.oteAmount);
                    }

                    if (totalAllocated > limits) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Strict Rule: Total ${budgetType.name} allocation (₹$totalAllocated) exceeds available budget (₹$limits)!'),
                          backgroundColor: Colors.red,
                        )
                      );
                      return; 
                    }

                    final cat = BudgetCategory(
                      id: '',
                      costCenterId: provider.activeCostCenterId!,
                      category: categoryController.text,
                      subCategory: subCategoryController.text,
                      budgetType: budgetType,
                      targetAmount: newAmount,
                      isActive: true,
                      remarks: remarksController.text,
                      createdAt: DateTime.now(),
                    );
                    await FirestoreService().addCategory(cat);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category added successfully!')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
