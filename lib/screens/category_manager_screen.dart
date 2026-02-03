import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/budget_category.dart';
import '../models/personal_adjustment.dart';
import '../models/cost_center_adjustment.dart';
import '../services/firestore_service.dart';
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
                    Tab(text: 'OTE (One-Time) (${oteCats.length})'),
                    Tab(text: 'PME (Recurring) (${pmeCats.length})'),
                  ],
                  indicatorColor: Colors.tealAccent,
                ),
                Expanded(
                  child: categories.isEmpty
                      ? const Center(child: Text('No categories found. Click + to add.'))
                      : TabBarView(
                          children: [
                            _buildCategoryList(context, provider, oteCats),
                            _buildCategoryList(context, provider, pmeCats),
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

  Widget _buildCategoryList(BuildContext context, AccountingProvider provider, List<BudgetCategory> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No categories in this section.'));
    }

    // Group items by main category
    final Map<String, List<BudgetCategory>> grouped = {};
    for (var item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    
    // Sort groups by name
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
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
                  Container(width: 4, height: 16, color: Colors.tealAccent, margin: const EdgeInsets.only(right: 8)),
                  Text(
                    mainCategory.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2, color: Colors.tealAccent),
                  ),
                  const Spacer(),
                  Text('${subItems.length} items', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            ...subItems.map((cat) {
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
                                      cat.subCategory, // Display Sub Category as the main card title now
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
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isOver ? Colors.redAccent : (progress > 0.8 ? Colors.orangeAccent : Colors.teal),
                                    ),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '₹${spent.toStringAsFixed(0)} / ₹${totalLimit.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
            }),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  // ... (Keep _showTransactions, _showDeleteConfirm, _showEditDialog as is or assumes they are untouched by this replacement range if I scope correctly, but I need to be careful with range)
  // I will skip replacing intermediate methods if I can, but I need to replace _showAddDialog which is at the end.
  // I'll assume I replace from _buildCategoryList start to end of file, effectively overwriting _showAddDialog too.
  
  // Wait, I need to keep _showTransactions + _showDeleteConfirm + _showEditDialog.
  // I will target _buildCategoryList separately, and _showAddDialog separately.

  // NOTE: I am not including the intermediate methods in this replacement block.
  // I will split this into two calls or use multi-replace.

  // Call 1: _buildCategoryList
  // Call 2: _showAddDialog (and FloatingActionButton update).
  // Ah, FAB is in build. I can't update FAB simply without replacing build or using the fact that I'm updating _showAddDialog signature?
  // Actually, Dart supports named args. `_showAddDialog(context)` is valid even if I add `template` as optional named.
  // So I don't need to change the FAB call site if the new arg is optional.
  
  // Revised Plan:
  // 1. Replace `_buildCategoryList`.
  // 2. Replace `_showAddDialog` with new signature `_showAddDialog(BuildContext context, {BudgetCategory? template})`.
  
  // Let's do multi_replace.

  void _showTransactions(BuildContext context, BudgetCategory cat) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final catExpenses = provider.expenses.where((e) => e.categoryId == cat.id).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: '${cat.subCategory} History',
          items: catExpenses,
          type: 'Expense',
          addScreen: const AddExpenseScreen(), 
          showEntryDetails: (context, item, type) {
            // Re-use detail viewer logic if needed
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
                    final updated = BudgetCategory(
                      id: cat.id,
                      costCenterId: cat.costCenterId,
                      category: categoryController.text,
                      subCategory: subCategoryController.text,
                      budgetType: budgetType,
                      targetAmount: double.tryParse(amountController.text) ?? 0.0,
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
                    final cat = BudgetCategory(
                      id: '',
                      costCenterId: provider.activeCostCenterId!,
                      category: categoryController.text,
                      subCategory: subCategoryController.text,
                      budgetType: budgetType,
                      targetAmount: double.tryParse(amountController.text) ?? 0.0,
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
