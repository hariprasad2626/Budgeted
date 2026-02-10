import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/budget_category.dart';
import '../models/personal_adjustment.dart';
import '../models/cost_center_adjustment.dart';
import '../models/fund_transfer.dart';
import '../services/firestore_service.dart';
import '../models/expense.dart';
import '../models/donation.dart';
import 'add_expense_screen.dart';
import 'transaction_history_screen.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            tooltip: 'Budget Allocations',
            onPressed: () => Navigator.pushNamed(context, '/manage-allocations'),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Consumer<AccountingProvider>(
          builder: (context, provider, child) {
            final categories = provider.categories;
            final oteCats = categories.where((c) => c.budgetType == BudgetType.OTE).toList();
            final pmeCats = categories.where((c) => c.budgetType == BudgetType.PME).toList();

            return Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'OTE (One-Time)'),
                    Tab(text: 'PME (Recurring)'),
                  ],
                  indicatorColor: Colors.tealAccent,
                ),
                Expanded(
                  child: categories.isEmpty
                      ? const Center(child: Text('No categories found. Click + to add.'))
                      : TabBarView(
                          children: [
                            _buildCategoryList(context, provider, oteCats, BudgetType.OTE),
                            _buildCategoryList(context, provider, pmeCats, BudgetType.PME),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, AccountingProvider provider, List<BudgetCategory> items, BudgetType type) {
    if (items.isEmpty) {
      return const Center(child: Text('No categories in this section.'));
    }

    // 1. Calculate Summary Totals
    double totalBudget = 0;
    double totalSpent = 0;
    double totalWalletSurplus = 0;

    for (var cat in items) {
      final status = provider.getCategoryStatus(cat);
      totalBudget += status['total_limit'] ?? 0;
      totalSpent += status['spent'] ?? 0;

      // Calculate Net Flow specifically for Wallet Surplus
      // Outgoing (To Wallet) - Incoming (From Wallet)
      final outgoingToWallet = provider.transfers
          .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId == cat.id && t.toCategoryId == null)
          .fold(0.0, (sum, t) => sum + t.amount);

      final incomingFromWallet = provider.transfers
          .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId == cat.id && t.fromCategoryId == null)
          .fold(0.0, (sum, t) => sum + t.amount);

      totalWalletSurplus += (outgoingToWallet - incomingFromWallet);
    }

    double progress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    bool isOver = totalSpent > totalBudget;

    // 2. Group Categories
    final Map<String, List<BudgetCategory>> grouped = {};
    for (var item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      children: [
        // --- Summary Card ---
        Card(
          margin: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryRow(context, 'Total ${type.name} Limit', totalBudget, isBoldTitle: true, fontSize: 16),
                const SizedBox(height: 8),
                _buildSummaryRow(context, 'Total Spent', totalSpent, valueColor: isOver ? Colors.red : null),
                const SizedBox(height: 4),
                _buildSummaryRow(
                  context, 
                  'Pending Balance', 
                  totalBudget - totalSpent, 
                  valueColor: (totalBudget - totalSpent) < 0 ? Colors.red : Colors.green.shade800
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context, 
                  'Excess to Wallet', 
                  totalWalletSurplus, 
                  valueColor: Colors.orange.shade800
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(isOver ? Colors.red : Colors.teal),
                  ),
                ),
              ],
            ),
          ),
        ),

        // --- Category List ---
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final mainCategory = sortedKeys[index];
              final subItems = grouped[mainCategory]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4, 
                          height: 16, 
                          color: Theme.of(context).colorScheme.primary, 
                          margin: const EdgeInsets.only(right: 8)
                        ),
                        Text(
                          mainCategory.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14, 
                            letterSpacing: 1.2, 
                            color: Theme.of(context).colorScheme.primary
                          ),
                        ),
                        const Spacer(),
                        Text('${subItems.length} items', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                      ],
                    ),
                  ),
                  ...subItems.map((cat) => _buildCategoryCard(context, provider, cat)).toList(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, double value, {bool isBoldTitle = false, double? fontSize, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontWeight: isBoldTitle ? FontWeight.bold : FontWeight.normal,
            color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(isBoldTitle ? 1.0 : 0.7)
          )
        ),
        Text(
          '₹${value.toStringAsFixed(0)}', 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: fontSize,
            color: valueColor ?? Theme.of(context).colorScheme.onTertiaryContainer
          )
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, AccountingProvider provider, BudgetCategory cat) {
    final status = provider.getCategoryStatus(cat);
    final double spent = status['spent']!;
    final double totalLimit = status['total_limit']!;
    final double progress = totalLimit > 0 ? (spent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final bool isOver = spent > totalLimit;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showTransactions(context, cat),
        onLongPress: () => _showEditDialog(context, cat),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.subCategory,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (cat.remarks.isNotEmpty)
                          Text(
                            cat.remarks,
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20, color: Colors.orangeAccent),
                        tooltip: 'Move Remaining to Wallet',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showTransferDialog(context, cat, true),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 20, color: Colors.greenAccent),
                        tooltip: 'Add Funds from Wallet',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showTransferDialog(context, cat, false),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.lightBlueAccent),
                        tooltip: 'Duplicate',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showAddDialog(context, template: cat),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showEditDialog(context, cat),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showDeleteConfirm(context, cat),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? Colors.redAccent : (progress > 0.8 ? Colors.orangeAccent : Colors.teal),
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${spent.toStringAsFixed(0)} / ₹${totalLimit.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pending: ₹${(totalLimit - spent).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: (totalLimit - spent) < 0 ? Colors.redAccent : Colors.green
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    
    // 1. Expenses
    final catExpenses = provider.expenses.where((e) => e.categoryId == cat.id).toList();

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

    // 5. Initial Allocation (The category itself)
    // We only add this if there is a target amount > 0, acting as the "Opening Balance" event
    final List<dynamic> allItems = [
      ...catExpenses,
      ...catDonations,
      ...catAdjustments,
      ...catTransfers,
    ];

    if (cat.targetAmount > 0) {
      allItems.add(cat);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: '${cat.subCategory} History',
          items: allItems,
          type: 'CategoryHistory', // Custom type to indicate mixed list
          addScreen: const AddExpenseScreen(), 
          contextEntityId: cat.id,
          showEntryDetails: (context, item, type) {
            // Helper to show details based on type
             if (item is Expense) {
                // ... (Existing logic for Expense)
             }
             // For now, we can leave this empty or implement a generic detail viewer if needed.
             // The list item row already shows key info.
          },
        ),
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
