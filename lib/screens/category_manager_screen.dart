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
            Icon(Icons.category_outlined, size: 84, color: Colors.teal.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text('No ${type.name} categories found', style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create First Category'),
            )
          ],
        ),
      );
    }

    // Unified summary calculations for the whole Project
    double totalBudget = 0;
    double totalSpent = 0;
    double totalActiveLimit = 0;

    for (var cat in provider.categories) {
      if (!cat.isActive || cat.budgetType != type) continue;
      final status = provider.getCategoryStatus(cat);
      totalBudget += status['budget'] ?? 0;
      totalSpent += status['spent'] ?? 0;
      totalActiveLimit += status['total_limit'] ?? 0;
    }

    final Map<String, List<BudgetCategory>> grouped = {};
    for (var item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    // Group-level budget calculations
    final Map<String, double> groupBudgets = {};
    for (var key in sortedKeys) {
      double groupTotal = 0;
      for (var cat in grouped[key]!) {
        final status = provider.getCategoryStatus(cat);
        groupTotal += status['total_limit'] ?? 0;
      }
      groupBudgets[key] = groupTotal;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // --- Premium Dashboard Header Section ---
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: provider.isDarkMode 
                  ? [Colors.teal.shade900.withOpacity(0.2), Colors.black.withOpacity(0)] 
                  : [Colors.teal.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${type.name} PERFORMANCE',
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w800, 
                            letterSpacing: 2.0,
                            color: Colors.teal.shade400
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${(totalActiveLimit - totalSpent).toStringAsFixed(0)} Remaining',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    _buildCircularProgress(context, totalSpent, totalActiveLimit),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Metric Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        context, 
                        'Total Limit', 
                        '₹${totalActiveLimit.toStringAsFixed(0)}', 
                        Icons.shield_outlined, 
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        context, 
                        'Total Spent', 
                        '₹${totalSpent.toStringAsFixed(0)}', 
                        Icons.account_balance_wallet_outlined, 
                        Colors.orange,
                        trend: totalActiveLimit > 0 ? (totalSpent / totalActiveLimit) : 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        context, 
                        'Master Wallet', 
                        '₹${provider.walletBalance.toStringAsFixed(0)}', 
                        Icons.savings_outlined, 
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
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
                  padding: const EdgeInsets.fromLTRB(24, 28, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        mainCategory,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${subItems.length} Categories',
                          style: TextStyle(fontSize: 10, color: Colors.teal.shade400, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${groupBudgets[mainCategory]!.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: provider.isDarkMode ? Colors.white70 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildEnhancedCategoryCard(context, provider, subItems[index]),
                    childCount: subItems.length,
                  ),
                ),
              ),
            ],
          );
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildCircularProgress(BuildContext context, double spent, double total) {
    double progress = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    Color color = progress > 0.9 ? Colors.red : (progress > 0.7 ? Colors.orange : Colors.teal);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 6,
            backgroundColor: Colors.teal.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildMetricTile(BuildContext context, String title, String value, IconData icon, Color color, {double? trend}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          if (trend != null)
             Container(
               margin: const EdgeInsets.only(top: 8),
               height: 3,
               width: 30,
               decoration: BoxDecoration(
                 color: color.withOpacity(0.2),
                 borderRadius: BorderRadius.circular(2),
               ),
               child: FractionallySizedBox(
                 alignment: Alignment.centerLeft,
                 widthFactor: trend.clamp(0.0, 1.0),
                 child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildEnhancedCategoryCard(BuildContext context, AccountingProvider provider, BudgetCategory cat) {
    final status = provider.getCategoryStatus(cat);
    final double spent = status['spent']!;
    final double totalLimit = status['total_limit']!;
    final double progress = totalLimit > 0 ? (spent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final bool isOver = spent > totalLimit;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.subCategory,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                      if (cat.remarks.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            cat.remarks, 
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w400),
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOver 
                              ? [Colors.red.shade400, Colors.red.shade700] 
                              : [Colors.teal.shade300, Colors.teal.shade600]
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: (isOver ? Colors.red : Colors.teal).withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${spent.toStringAsFixed(0)} / ₹${totalLimit.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey : Colors.grey.shade700),
                    ),
                    Text(
                      isOver ? '₹${(spent - totalLimit).toStringAsFixed(0)} Over' : '₹${(totalLimit - spent).toStringAsFixed(0)} Left',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w800,
                        color: isOver ? Colors.redAccent : Colors.teal.shade400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.teal.shade400),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    const Divider(height: 24),
                    // Action Control Center
                    Row(
                      children: [
                         _buildModernAction(context, 'Withdraw', Icons.remove_circle_outline, Colors.orange, () => _openInternalTransfer(context, cat, true)),
                         const SizedBox(width: 8),
                         _buildModernAction(context, 'Top Up', Icons.add_circle_outline, Colors.green, () => _openInternalTransfer(context, cat, false)),
                         const SizedBox(width: 8),
                         _buildModernAction(context, 'History', Icons.history_rounded, Colors.blue, () => _showTransactions(context, cat)),
                         const SizedBox(width: 8),
                         _buildModernAction(context, 'Settings', Icons.settings_outlined, Colors.grey, () => _showMoreActions(context, cat)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Glassmorphic Detail Panel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Monthly Allotment', '₹${status['budget']?.toStringAsFixed(0)}', icon: Icons.calendar_month),
                          _buildDetailRow('Active Duration', '${provider.getElapsedMonthsForCategory(cat)} Months', icon: Icons.timer_outlined),
                          _buildDetailRow('External Donations', '₹${status['donations']?.toStringAsFixed(0)}', icon: Icons.volunteer_activism, color: Colors.green),
                          _buildDetailRow('Net Transfers', '₹${status['transfers']?.toStringAsFixed(0)}', icon: Icons.swap_horiz, color: Colors.purple),
                          _buildDetailRow('Balance Adjustments', '₹${status['adjustments']?.toStringAsFixed(0)}', icon: Icons.edit_note, color: Colors.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label, 
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.w700, 
                  letterSpacing: 0.2,
                  color: isDark ? Colors.white70 : Colors.black87
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {IconData? icon, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 8),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  void _openInternalTransfer(BuildContext context, BudgetCategory cat, bool isFromCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransferScreen(
          initialType: TransferType.CATEGORY_TO_CATEGORY,
          prefilledCategoryId: cat.id,
          isPrefilledAsSource: isFromCategory,
        ),
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
