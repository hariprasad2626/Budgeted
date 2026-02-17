import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/donation.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../models/cost_center_adjustment.dart';

import '../models/budget_category.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String title;
  final List<dynamic>? items;
  final List<dynamic> Function(AccountingProvider)? itemSelector;
  final String type;
  final Widget addScreen;
  final Function(BuildContext, dynamic, String) showEntryDetails;
  final String? contextEntityId; // Optional: ID of the entity (Category/CostCenter) we are viewing history for

  const TransactionHistoryScreen({
    super.key,
    this.items,
    this.itemSelector,
    required this.title,
    required this.type,
    required this.addScreen,
    required this.showEntryDetails,
    this.contextEntityId,
  }) : assert(items != null || itemSelector != null, 'Either items or itemSelector must be provided');

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        final itemsSource = widget.itemSelector != null ? widget.itemSelector!(provider) : widget.items!;
        final sortedItems = List.from(itemsSource)..sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));

        double selectedSum = sortedItems
            .where((item) => _selectedIds.contains(item.id))
            .fold(0.0, (sum, item) {
              double amount = item.amount ?? 0.0;
              bool isCredit = false;
              
              if (item is Donation) isCredit = true;
              else if (item is FundTransfer) {
                if (item.type != TransferType.CATEGORY_TO_CATEGORY) {
                  isCredit = true; // Advance
                } else {
                  // Context-aware check
                  if (widget.contextEntityId != null && item.toCategoryId == widget.contextEntityId) {
                    isCredit = true;
                  } else {
                    isCredit = false; 
                  }
                }
              }
              else if (item is PersonalAdjustment && item.type == AdjustmentType.CREDIT) isCredit = true;
              else if (item is CostCenterAdjustment && item.type == AdjustmentType.CREDIT) isCredit = true;
              else if (item is BudgetCategory) isCredit = true; 
              
              return sum + (isCredit ? amount : -amount);
            });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.tealAccent, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => widget.addScreen),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.teal.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Sum:', style: TextStyle(fontSize: 14, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Text(
                        '₹${selectedSum.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _selectedIds.clear()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: itemsSource.isEmpty
                ? const Center(child: Text('No entries found.'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedItems.length,
                    separatorBuilder: (context, index) => Divider(color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade300, height: 1),
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      final bool isSelected = _selectedIds.contains(item.id);
                      
                      // Determine transaction properties
                      bool isCredit = false;
                      Color itemColor = Colors.redAccent;
                      IconData itemIcon = Icons.arrow_upward;
                      String amountPrefix = '-';
                      String categoryLabel = '';
                      
                      if (item is Expense) {
                        isCredit = false;
                        itemColor = Colors.redAccent;
                        itemIcon = Icons.arrow_upward;
                        amountPrefix = '-';
                        try {
                          final cat = provider.categories.firstWhere((c) => c.id == item.categoryId);
                          categoryLabel = '${cat.category} > ${cat.subCategory}';
                        } catch (_) {
                          categoryLabel = 'Direct Expense';
                        }
                      } else if (item is Donation) {
                        isCredit = true;
                        itemColor = Colors.greenAccent;
                        itemIcon = Icons.arrow_downward;
                        amountPrefix = '+';
                        categoryLabel = 'Donation Received';
                      } else if (item is FundTransfer) {
                        if (item.type == TransferType.CATEGORY_TO_CATEGORY) {
                           String fromName = 'Unallocated';
                           String toName = 'Unallocated';
                           try {
                              if (item.fromCategoryId != null) {
                                final f = provider.categories.firstWhere((c) => c.id == item.fromCategoryId);
                                fromName = f.subCategory;
                              }
                              if (item.toCategoryId != null) {
                                final t = provider.categories.firstWhere((c) => c.id == item.toCategoryId);
                                toName = t.subCategory;
                              }
                           } catch (_) {}
                           
                           categoryLabel = '$fromName -> $toName';

                           if (widget.contextEntityId != null) {
                             if (item.toCategoryId == widget.contextEntityId) {
                               isCredit = true;
                               itemColor = Colors.greenAccent;
                               itemIcon = Icons.arrow_downward;
                               amountPrefix = '+';
                             } else {
                               isCredit = false;
                               itemColor = Colors.orangeAccent;
                               itemIcon = Icons.arrow_upward;
                               amountPrefix = '-';
                             }
                           } else {
                             // Fallback for non-context view
                             itemColor = Colors.grey;
                             itemIcon = Icons.swap_horiz;
                             amountPrefix = '';
                           }
                        } else {
                           isCredit = true;
                           itemColor = Colors.greenAccent;
                           itemIcon = Icons.arrow_downward;
                           amountPrefix = '+';
                           categoryLabel = 'Advance Received';
                        }
                      } else if (item is PersonalAdjustment) {
                        isCredit = item.type == AdjustmentType.CREDIT;
                        itemColor = isCredit ? Colors.greenAccent : Colors.orangeAccent;
                        itemIcon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
                        amountPrefix = isCredit ? '+' : '-';
                        categoryLabel = 'Personal Adjustment';
                      } else if (item is CostCenterAdjustment) {
                        isCredit = item.type == AdjustmentType.CREDIT;
                        itemColor = isCredit ? Colors.greenAccent : Colors.orangeAccent;
                        itemIcon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
                        amountPrefix = isCredit ? '+' : '-';
                        try {
                          final cat = provider.categories.firstWhere((c) => c.id == item.categoryId);
                          categoryLabel = 'Adjustment: ${cat.subCategory}';
                        } catch (_) {
                          categoryLabel = 'Adjustment';
                        }
                      } else if (item is BudgetCategory) {
                        isCredit = true;
                        itemColor = Colors.blueAccent;
                        itemIcon = Icons.account_balance_wallet;
                        amountPrefix = '+'; // Initial allocation adds to balance
                        categoryLabel = item.subCategory;
                      }

                      return InkWell(
                        onTap: () => widget.showEntryDetails(context, item, widget.type == 'PersonalAdjustment' ? 'Adjustment' : widget.type),
                        child: Container(
                          color: isSelected ? Colors.teal.withOpacity(0.1) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(item.id);
                                      } else {
                                        _selectedIds.remove(item.id);
                                      }
                                    });
                                  },
                                  activeColor: Colors.tealAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  itemIcon,
                                  color: itemColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),


                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(item.date),
                                      style: TextStyle(color: provider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.remarks,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: provider.isDarkMode ? null : Colors.black87),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (categoryLabel.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          categoryLabel,
                                          style: TextStyle(color: provider.isDarkMode ? Colors.white60 : Colors.black54, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$amountPrefix₹${item.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: itemColor,
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
}
