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
  final String? contextEntityId; 

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
  bool _isSelectionMode = false;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  bool _isGroupedView = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              decoration: const InputDecoration(hintText: 'Search remarks...', border: InputBorder.none, hintStyle: TextStyle(color: Colors.white70)),
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              onChanged: (val) => setState(() => _searchQuery = val),
            )
          : Text(widget.title),
        backgroundColor: Colors.teal.shade900,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            onPressed: () => setState(() => _isGroupedView = !_isGroupedView),
            icon: Icon(_isGroupedView ? Icons.access_time : Icons.group_work),
            tooltip: _isGroupedView ? 'Timeline' : 'Grouped',
          ),
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
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final itemsSource = widget.itemSelector != null ? widget.itemSelector!(provider) : widget.items!;
          
          // Apply Filters
          var filtered = List.from(itemsSource);
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((item) => (item.remarks as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }
          if (_selectedDateRange != null) {
            filtered = filtered.where((item) {
              final d = item.date as DateTime;
              return d.isAfter(_selectedDateRange!.start.subtract(const Duration(days:1))) &&
                     d.isBefore(_selectedDateRange!.end.add(const Duration(days:1)));
            }).toList();
          }

          final sortedItems = filtered..sort((a, b) => (b.date as DateTime).compareTo(a.date as DateTime));

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

          return Column(
            children: [
               // Premium Selection Header
               if (_isSelectionMode || _selectedIds.isNotEmpty)
                 Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: provider.isDarkMode ? Colors.teal.withOpacity(0.15) : Colors.teal.shade50,
                    border: const Border(bottom: BorderSide(color: Colors.tealAccent, width: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _selectedIds.length == sortedItems.length && sortedItems.isNotEmpty,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.addAll(sortedItems.map<String>((e) => e.id as String));
                                  _isSelectionMode = true;
                                } else {
                                  _selectedIds.clear();
                                  _isSelectionMode = false;
                                }
                              });
                            },
                            activeColor: Colors.tealAccent,
                          ),
                          const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '₹${selectedSum.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => setState(() {
                              _selectedIds.clear();
                              _isSelectionMode = false;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Filters/Date Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${sortedItems.length} entries matching',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2030),
                          initialDateRange: _selectedDateRange,
                        );
                        if (picked != null) setState(() => _selectedDateRange = picked);
                      },
                      icon: Icon(Icons.calendar_today, size: 20, color: _selectedDateRange != null ? Colors.tealAccent : Colors.grey),
                    ),
                    if (_selectedDateRange != null)
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _selectedDateRange = null)),
                  ],
                ),
              ),

              Expanded(
                child: sortedItems.isEmpty
                    ? const Center(child: Text('No entries found.'))
                    : _isGroupedView ? _buildGroupedView(sortedItems, provider) : _buildTimelineView(sortedItems, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineView(List<dynamic> items, AccountingProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (context, index) => Divider(color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade300, height: 1),
      itemBuilder: (context, index) => _buildEntryRow(items[index], provider),
    );
  }

  Widget _buildGroupedView(List<dynamic> items, AccountingProvider provider) {
    final groups = <String, List<dynamic>>{};
    for (var item in items) {
      final date = item.date as DateTime;
      final key = DateFormat('MMMM yyyy').format(date);
      groups.putIfAbsent(key, () => []).add(item);
    }
    
    return ListView(
      padding: const EdgeInsets.all(8),
      children: groups.keys.map((groupKey) {
        final groupItems = groups[groupKey]!;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(groupKey, style: const TextStyle(fontWeight: FontWeight.bold)),
            children: groupItems.map((item) => _buildEntryRow(item, provider)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEntryRow(dynamic item, AccountingProvider provider) {
    final bool isSelected = _selectedIds.contains(item.id);
    
    bool isCredit = false;
    Color itemColor = Colors.redAccent;
    IconData itemIcon = Icons.arrow_upward;
    String amountPrefix = '-';
    String categoryLabel = '';
    
    if (item is Expense) {
      isCredit = false; itemColor = Colors.redAccent; itemIcon = Icons.arrow_upward; amountPrefix = '-';
      try {
        final cat = provider.categories.firstWhere((c) => c.id == item.categoryId);
        categoryLabel = '${cat.category} > ${cat.subCategory}';
      } catch (_) { categoryLabel = 'Direct Expense'; }
    } else if (item is Donation) {
      isCredit = true; itemColor = Colors.greenAccent; itemIcon = Icons.arrow_downward; amountPrefix = '+';
      categoryLabel = 'Donation';
    } else if (item is FundTransfer) {
      if (item.type == TransferType.CATEGORY_TO_CATEGORY) {
         categoryLabel = 'Category Transfer';
         if (widget.contextEntityId != null) {
           if (item.toCategoryId == widget.contextEntityId) {
             isCredit = true; itemColor = Colors.greenAccent; itemIcon = Icons.arrow_downward; amountPrefix = '+';
           } else {
             isCredit = false; itemColor = Colors.orangeAccent; itemIcon = Icons.arrow_upward; amountPrefix = '-';
           }
         } else {
           itemColor = Colors.grey; itemIcon = Icons.swap_horiz; amountPrefix = '';
         }
      } else {
         isCredit = true; itemColor = Colors.greenAccent; itemIcon = Icons.arrow_downward; amountPrefix = '+';
         categoryLabel = 'Advance';
      }
    } else if (item is PersonalAdjustment || item is CostCenterAdjustment) {
      isCredit = (item.type == AdjustmentType.CREDIT);
      itemColor = isCredit ? Colors.greenAccent : Colors.orangeAccent;
      itemIcon = isCredit ? Icons.arrow_downward : Icons.arrow_upward;
      amountPrefix = isCredit ? '+' : '-';
      categoryLabel = 'Adjustment';
    } else if (item is BudgetCategory) {
      isCredit = true; itemColor = Colors.blueAccent; itemIcon = Icons.account_balance_wallet; amountPrefix = '+';
      categoryLabel = item.subCategory;
    }

    return InkWell(
      onLongPress: () => _toggleSelection(item.id),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(item.id);
        } else {
          widget.showEntryDetails(context, item, widget.type == 'PersonalAdjustment' ? 'Adjustment' : widget.type);
        }
      },
      child: Container(
        color: isSelected ? Colors.teal.withOpacity(0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(item.id),
                activeColor: Colors.tealAccent,
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: itemColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(itemIcon, color: itemColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd, yyyy').format(item.date), style: TextStyle(color: provider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(item.remarks, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: provider.isDarkMode ? null : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (categoryLabel.isNotEmpty) Text(categoryLabel, style: TextStyle(color: provider.isDarkMode ? Colors.white60 : Colors.black54, fontSize: 11)),
                ],
              ),
            ),
            Text(
              '$amountPrefix₹${item.amount.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: itemColor),
            ),
          ],
        ),
      ),
    );
  }
}
