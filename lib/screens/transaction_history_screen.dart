import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/donation.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../models/cost_center_adjustment.dart';

class TransactionHistoryScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final String type;
  final Widget addScreen;
  final Function(BuildContext, dynamic, String) showEntryDetails;

  const TransactionHistoryScreen({
    super.key,
    required this.title,
    required this.items,
    required this.type,
    required this.addScreen,
    required this.showEntryDetails,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final sortedItems = List.from(items)..sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.tealAccent, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => addScreen),
              );
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No entries found.'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sortedItems.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                
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
                     // Neutral styling for Internal Transfers
                     itemColor = Colors.grey;
                     itemIcon = Icons.swap_horiz;
                     amountPrefix = '';
                     
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
                  } else {
                     // Advance Received (Credit)
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
                }

                return InkWell(
                  onTap: () => showEntryDetails(context, item, type == 'PersonalAdjustment' ? 'Adjustment' : type),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Icon Circle
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
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('MMM dd, yyyy').format(item.date),
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.remarks,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (categoryLabel.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    categoryLabel,
                                    style: TextStyle(color: Colors.white60, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Amount
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
    );
  }
}
