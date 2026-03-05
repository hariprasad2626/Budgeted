import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../models/donation.dart';
import '../models/budget_category.dart';
import '../services/firestore_service.dart';
import 'add_expense_screen.dart';
import 'add_donation_screen.dart';
import 'add_adjustment_screen.dart';
import 'add_transfer_screen.dart';

class PersonalLedgerScreen extends StatefulWidget {
  const PersonalLedgerScreen({super.key});

  @override
  State<PersonalLedgerScreen> createState() => _PersonalLedgerScreenState();
}

class _PersonalLedgerScreenState extends State<PersonalLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedExpenseIds = {};
  final Set<String> _selectedHistoryIds = {};
  
  // Search & Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  bool _isGroupedView = false;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id, bool isHistory) {
    setState(() {
      final targetSet = isHistory ? _selectedHistoryIds : _selectedExpenseIds;
      if (targetSet.contains(id)) {
        targetSet.remove(id);
        if (_selectedExpenseIds.isEmpty && _selectedHistoryIds.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        targetSet.add(id);
      }
    });
  }

  Future<void> _settleSelectedExpenses(List<Expense> allPending) async {
    if (_selectedExpenseIds.isEmpty) return;
    
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final service = FirestoreService();
    
    // Fetch all categories for the selection
    final allCategories = await service.getAllCategories();
    final costCenters = provider.costCenters;

    if (!mounted) return;

    String? selectedCategoryId;
    String? selectedCostCenterId;
    bool useExisting = false;
    bool againstAdvance = true; // Default to against advance as suggested by user flow

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredCats = allCategories.where((c) => c.costCenterId == selectedCostCenterId).toList();
          
          return AlertDialog(
            title: Text('Settle ${_selectedExpenseIds.length} Expenses (v${AccountingProvider.appVersion})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Settlement Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.tealAccent)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => againstAdvance = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: againstAdvance ? Colors.teal.shade800 : null,
                                borderRadius: BorderRadius.circular(8),
                                border: againstAdvance ? Border.all(color: Colors.tealAccent) : null,
                              ),
                              child: Center(child: Text('Against Advance', style: TextStyle(color: againstAdvance ? Colors.white : Colors.grey, fontWeight: againstAdvance ? FontWeight.bold : FontWeight.normal))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setDialogState(() => againstAdvance = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !againstAdvance ? Colors.blue.shade800 : null,
                                borderRadius: BorderRadius.circular(8),
                                border: !againstAdvance ? Border.all(color: Colors.blueAccent) : null,
                              ),
                              child: Center(child: Text('Reimbursement', style: TextStyle(color: !againstAdvance ? Colors.white : Colors.grey, fontWeight: !againstAdvance ? FontWeight.bold : FontWeight.normal))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    againstAdvance 
                      ? '• No bank reduction (uses existing advance).' 
                      : '• Reduces bank balance (new cash outflow).',
                    style: TextStyle(fontSize: 11, color: againstAdvance ? Colors.tealAccent.withOpacity(0.7) : Colors.blueAccent.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Classify Entries:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  CheckboxListTile(
                    title: const Text('Keep existing categories', style: TextStyle(fontSize: 14)),
                    value: useExisting, 
                    onChanged: (val) {
                      setDialogState(() {
                        useExisting = val ?? false;
                        if (useExisting) {
                          selectedCostCenterId = null;
                          selectedCategoryId = null;
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!useExisting) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Select Cost Center', border: OutlineInputBorder()),
                      value: selectedCostCenterId,
                      items: costCenters.map((cc) => DropdownMenuItem(value: cc.id, child: Text(cc.name))).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCostCenterId = val;
                          selectedCategoryId = null;
                        });
                      },
                    ),
                    if (selectedCostCenterId != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
                        value: selectedCategoryId,
                        items: filteredCats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.category} > ${c.subCategory}'))).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedCategoryId = val);
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (useExisting || selectedCategoryId != null) ? () async {
                  int count = 0;
                  BudgetCategory? targetCat;
                  if (!useExisting) {
                    targetCat = allCategories.firstWhere((c) => c.id == selectedCategoryId);
                  }
                  
                  for (var id in _selectedExpenseIds) {
                    try {
                      final expense = allPending.firstWhere((e) => e.id == id);
                      
                      // Use target info if provided, otherwise keep existing
                      final finalCcId = targetCat?.costCenterId ?? expense.costCenterId;
                      final finalCatId = targetCat?.id ?? expense.categoryId;
                      final finalBType = targetCat?.budgetType ?? expense.budgetType;

                      final updated = Expense(
                        id: expense.id,
                        costCenterId: finalCcId,
                        categoryId: finalCatId,
                        amount: expense.amount,
                        budgetType: finalBType,
                        moneySource: expense.moneySource,
                        date: expense.date,
                        remarks: expense.remarks,
                        isSettled: true,
                        settledAgainstAdvance: againstAdvance,
                      );
                      await service.updateExpense(updated, previousData: expense);
                      count++;
                    } catch (e) {
                      debugPrint('Error settling expense: $e');
                    }
                  }
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  setState(() {
                    _selectedExpenseIds.clear();
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Expenses Settled!')));
                  }
                } : null,
                child: const Text('Settle Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getCostCenterName(AccountingProvider provider, String id) {
    try {
      return provider.costCenters.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return 'Unknown Center';
    }
  }

  String _getCategoryPath(AccountingProvider provider, String categoryId) {
    try {
      final cat = provider.categories.firstWhere((c) => c.id == categoryId);
      return '${cat.category} -> ${cat.subCategory}';
    } catch (_) {
      return 'Unknown Category';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        // --- 1. Prepare Data ---

        // Pending Expenses
        List<Expense> pendingExpenses = provider.allExpenses 
            .where((e) => e.moneySource == MoneySource.PERSONAL && !e.isSettled)
            .toList();

        // History Entries
        final List<Map<String, dynamic>> historyEntries = [];

        // Add Fixed Amounts
        for (var f in provider.fixedAmounts) {
          historyEntries.add({
            'title': f.remarks,
            'subtitle': 'Opening / Fixed Balance',
            'dateLine': DateFormat('dd MMM yyyy').format(f.createdAt),
            'amount': f.amount,
            'date': f.createdAt,
            'type': 'Fixed',
            'color': Colors.amberAccent,
            'item': f,
            'uniqueKey': f.id,
            'searchBlob': '${f.remarks} opening fixed ${f.amount}'.toLowerCase(),
          });
        }

        // Add Transfers (Advances)
        for (var t in provider.transfers.where((t) => t.type == TransferType.TO_PERSONAL)) {
          final ccName = _getCostCenterName(provider, t.costCenterId);
          historyEntries.add({
            'title': 'Advance from $ccName',
            'subtitle': '', 
            'dateLine': DateFormat('dd MMM yyyy').format(t.date),
            'meta': t.remarks, // Show remarks in meta line
            'amount': t.amount,
            'date': t.date,
            'type': 'Transfer',
            'color': Colors.blueAccent,
            'item': t,
            'uniqueKey': t.id,
            'searchBlob': 'advance from $ccName ${t.remarks} ${t.amount}'.toLowerCase(),
          });
        }

        // Add Settled Expenses
        for (var e in provider.allExpenses.where((x) => x.moneySource == MoneySource.PERSONAL && x.isSettled)) {
          final ccName = _getCostCenterName(provider, e.costCenterId);
          final catPath = _getCategoryPath(provider, e.categoryId);
          
          // The Expense itself (Negative)
          historyEntries.add({
            'title': e.remarks,
            'subtitle': '$ccName -> $catPath',
            'dateLine': DateFormat('dd MMM yyyy').format(e.date),
            'amount': -e.amount,
            'date': e.date,
            'type': 'Expense',
            'color': Colors.redAccent,
            'item': e,
            'uniqueKey': e.id,
            'searchBlob': '${e.remarks} $ccName $catPath ${e.amount}'.toLowerCase(),
          });

          // The Reimbursement (Positive) - if not settled against advance
          if (!e.settledAgainstAdvance) {
            historyEntries.add({
              'title': 'Reimbursement: ${e.remarks}',
              'subtitle': 'Credit to Pocket',
              'dateLine': DateFormat('dd MMM yyyy').format(e.date),
              'amount': e.amount,
              'date': e.date,
              'type': 'Reimbursement',
              'color': Colors.tealAccent,
              'item': e,
              'uniqueKey': 'reimb_${e.id}',
              'searchBlob': 'reimbursement ${e.remarks} ${e.amount}'.toLowerCase(),
            });
          }
        }

        // Add Manual Adjustments
        for (var a in provider.adjustments) {
          historyEntries.add({
            'title': a.remarks,
            'subtitle': 'Manual Entry',
            'dateLine': DateFormat('dd MMM yyyy').format(a.date),
            'amount': a.type == AdjustmentType.CREDIT ? a.amount : -a.amount,
            'date': a.date,
            'type': 'Adjustment',
            'color': a.type == AdjustmentType.CREDIT ? Colors.greenAccent : Colors.orangeAccent,
            'item': a,
            'uniqueKey': a.id,
            'searchBlob': '${a.remarks} manual entry ${a.amount}'.toLowerCase(),
          });
        }

        // --- 2. Filter & Sort ---
        if (_searchQuery.isNotEmpty) {
          pendingExpenses = pendingExpenses.where((e) {
            final ccName = _getCostCenterName(provider, e.costCenterId);
            final blob = '${e.remarks} $ccName ${e.amount}'.toLowerCase();
            return blob.contains(_searchQuery);
          }).toList();

          historyEntries.retainWhere((entry) => (entry['searchBlob'] as String).contains(_searchQuery));
        }

        if (_selectedDateRange != null) {
          pendingExpenses = pendingExpenses.where((e) => 
            e.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
            e.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)))).toList();
          
          historyEntries.retainWhere((e) {
            final date = e['date'] as DateTime;
            return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                   date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          });
        }

        pendingExpenses.sort((a, b) => b.date.compareTo(a.date));
        historyEntries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        double pendingSum = pendingExpenses
            .where((e) => _selectedExpenseIds.contains(e.id))
            .fold(0.0, (sum, e) => sum - e.amount); // Expenses reduce pocket balance
        
        double historySum = historyEntries
            .where((e) => _selectedHistoryIds.contains(e['uniqueKey']))
            .fold(0.0, (sum, e) => sum + (e['amount'] as double));
        
        double totalSelectionSum = pendingSum + historySum;
        bool hasSelection = _selectedExpenseIds.isNotEmpty || _selectedHistoryIds.isNotEmpty;


        // --- 3. Build UI ---
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal.shade800,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search remarks/centers...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  )
                : const Text('Personal Pocket Ledger'),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchController.clear();
                      _searchQuery = '';
                    } else {
                      _isSearching = true;
                    }
                  });
                },
              ),
              IconButton(
                onPressed: () => setState(() => _isGroupedView = !_isGroupedView),
                icon: Icon(_isGroupedView ? Icons.access_time : Icons.group_work),
                tooltip: _isGroupedView ? 'Timeline' : 'Grouped',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.tealAccent,
              tabs: [
                Tab(text: 'Pending (${pendingExpenses.length})'),
                Tab(text: 'History (${historyEntries.length})'),
              ],
            ),
          ),
          floatingActionButton: _tabController.index == 0 && _selectedExpenseIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () => _settleSelectedExpenses(pendingExpenses),
                label: Text('Settle ${_selectedExpenseIds.length} Expenses'),
                icon: const Icon(Icons.check),
                backgroundColor: Colors.tealAccent.shade700,
              )
            : null,
          body: Column(
            children: [
               if (!_isSearching)
                 Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: provider.isDarkMode ? Colors.teal.withOpacity(0.1) : Colors.teal.shade50,
                    border: Border(bottom: BorderSide(color: Colors.teal.withOpacity(0.3))),
                  ),
                  child: Column(
                    children: [
                      Text('Current Pocket Balance', style: TextStyle(fontSize: 14, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade800)),
                      const SizedBox(height: 4),
                      const SizedBox(height: 4),
                      Text(
                        '₹${provider.personalBalance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: provider.isDarkMode ? Colors.white : Colors.teal.shade900),
                      ),
                      Text('Balance includes all advances and unssettled expenses.', style: TextStyle(fontSize: 12, color: provider.isDarkMode ? Colors.grey : Colors.grey.shade700)),
                      
                      // Filter Row
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                              style: IconButton.styleFrom(backgroundColor: provider.isDarkMode ? Colors.white10 : Colors.teal.shade100),
                            ),
                            if (_selectedDateRange != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _selectedDateRange = null),
                              ),
                        ],
                      ),

                      if (_isSelectionMode || hasSelection) ...[
                        Divider(height: 24, color: provider.isDarkMode ? Colors.white24 : Colors.teal.withOpacity(0.3)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _tabController.index == 0 
                                      ? (_selectedExpenseIds.length == pendingExpenses.length && pendingExpenses.isNotEmpty)
                                      : (_selectedHistoryIds.length == historyEntries.length && historyEntries.isNotEmpty),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _isSelectionMode = true;
                                        if (_tabController.index == 0) {
                                          _selectedExpenseIds.addAll(pendingExpenses.map((e) => e.id));
                                        } else {
                                          _selectedHistoryIds.addAll(historyEntries.map((e) => e['uniqueKey'] as String));
                                        }
                                      } else {
                                        _selectedExpenseIds.clear();
                                        _selectedHistoryIds.clear();
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
                                  '₹${totalSelectionSum.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade800),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18, color: provider.isDarkMode ? Colors.grey : Colors.grey.shade700),
                                  onPressed: () => setState(() {
                                    _selectedExpenseIds.clear();
                                    _selectedHistoryIds.clear();
                                    _isSelectionMode = false;
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Pending
                      _isGroupedView 
                        ? _buildGroupedPendingList(context, pendingExpenses)
                        : _buildPendingList(context, pendingExpenses),
                      
                      // Tab 2: History
                      _isGroupedView
                        ? _buildGroupedHistoryList(historyEntries)
                        : _buildHistoryList(historyEntries),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingList(BuildContext context, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return Center(child: Text(_searchQuery.isNotEmpty ? 'No matches found.' : 'No pending expenses.'));
    }
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: expenses.length,
      separatorBuilder: (_, __) => Divider(color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade300, height: 1),
      itemBuilder: (context, index) => _buildPendingRow(context, expenses[index], provider),
    );
  }

  Widget _buildGroupedPendingList(BuildContext context, List<Expense> expenses) {
    if (expenses.isEmpty) {
      return Center(child: Text(_searchQuery.isNotEmpty ? 'No matches found.' : 'No pending expenses.'));
    }

    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final Map<String, List<Expense>> grouped = {};
    for (var e in expenses) {
      if (!grouped.containsKey(e.costCenterId)) grouped[e.costCenterId] = [];
      grouped[e.costCenterId]!.add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final costCenterId = grouped.keys.elementAt(index);
        final centerExpenses = grouped[costCenterId]!;
        final centerName = _getCostCenterName(provider, costCenterId);

        double groupTotal = centerExpenses.fold(0.0, (sum, e) => sum + e.amount);

        return Card(
           margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
           elevation: 0,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
           child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(centerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${centerExpenses.length} items • ₹${groupTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
              children: centerExpenses.map((e) => _buildPendingRow(context, e, provider)).toList(),
           ),
        );
      },
    );
  }

  Widget _buildPendingRow(BuildContext context, Expense e, AccountingProvider provider) {
    final isSelected = _selectedExpenseIds.contains(e.id);
    final catPath = _getCategoryPath(provider, e.categoryId);

    return InkWell(
      onLongPress: () => _toggleSelection(e.id, false),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(e.id, false);
        } else {
          _showEntryDetails(context, e, 'Expense');
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
                onChanged: (val) => _toggleSelection(e.id, false),
                activeColor: Colors.tealAccent,
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward, color: Colors.redAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd, yyyy').format(e.date), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(e.remarks, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1),
                  Text(catPath, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text('-₹${e.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedHistoryList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return Center(child: Text(_searchQuery.isNotEmpty ? 'No matches found.' : 'No history found.'));
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (var e in entries) {
      final key = DateFormat('MMMM yyyy').format(e['date'] as DateTime);
      groups.putIfAbsent(key, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: groups.keys.map((groupKey) {
        final items = groups[groupKey]!;
        double groupSum = items.fold(0.0, (sum, e) => sum + (e['amount'] as double));
        final isPositive = groupSum >= 0;

        return Card(
           margin: const EdgeInsets.only(bottom: 8),
           elevation: 0,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
           child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(groupKey, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${items.length} items • ₹${groupSum.abs().toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
              children: items.map((e) => _buildHistoryRow(e)).toList(),
           ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return Center(child: Text(_searchQuery.isNotEmpty ? 'No matches found.' : 'No history found.'));
    }
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: provider.isDarkMode ? Colors.white10 : Colors.grey.shade300),
          itemBuilder: (context, index) => _buildHistoryRow(entries[index]),
        );
      }
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> entry) {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    final amount = entry['amount'] as double;
    final isPositive = amount > 0;
    final title = entry['title'] as String;
    final subtitle = entry['subtitle'] as String;
    final dateLine = entry['dateLine'] as String;
    final meta = entry['meta'];
    final String uniqueId = entry['uniqueKey'];
    final bool isSelected = _selectedHistoryIds.contains(uniqueId);

    return InkWell(
      onLongPress: () => _toggleSelection(uniqueId, true),
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(uniqueId, true);
        } else {
          _showEntryDetails(context, entry['item'], entry['type']);
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
                onChanged: (val) => _toggleSelection(uniqueId, true),
                activeColor: Colors.tealAccent,
              ),
              const SizedBox(width: 4),
            ],
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: (entry['color'] as Color).withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(isPositive ? Icons.arrow_downward : Icons.arrow_upward, color: entry['color'], size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLine, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1),
                  if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (meta != null && meta.toString().isNotEmpty) 
                    Text(meta, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              '${isPositive ? '+' : '-'}${amount.abs().toStringAsFixed(0)}',
              style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
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
            child: Text('Personal Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.tealAccent),
              title: const Text('Personal Expenses Entry'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddExpenseScreen(defaultSource: MoneySource.PERSONAL)); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
              title: const Text('Record Advance Received'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddTransferScreen(initialType: TransferType.TO_PERSONAL)); },
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

  void _showEntryDetails(BuildContext context, dynamic item, String type) {
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
    try {
      final cc = provider.costCenters.where((c) => c.id == item.costCenterId).toList();
      if (cc.isNotEmpty) costCenterName = cc.first.name;
    } catch (_) {}

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
              if ((item as Expense).moneySource == MoneySource.PERSONAL)
                Text('Status: ${item.isSettled ? "Settled" : "Pending Settlement"}', style: TextStyle(color: item.isSettled ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
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
          if (type == 'Expense' && (item as Expense).isSettled)
            TextButton(
              onPressed: () => _unsettleExpense(context, item),
              child: const Text('Unsettle', style: TextStyle(color: Colors.orangeAccent)),
            ),
          
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'Expense') {
                _showForm(context, AddExpenseScreen(expenseToEdit: item as Expense));
              } else if (type == 'Donation') {
                _showForm(context, AddDonationScreen(donationToEdit: item as Donation));
              } else if (type == 'Adjustment') {
                _showForm(context, AddAdjustmentScreen(adjustmentToEdit: item as PersonalAdjustment));
              } else if (type == 'Transfer') {
                _showForm(context, AddTransferScreen(transferToEdit: item as FundTransfer));
              }
            },
            child: const Text('Edit'),
          ),

          TextButton(
            onPressed: () => _confirmDelete(context, item, type),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _unsettleExpense(BuildContext context, Expense expense) async {
    try {
      final updated = Expense(
        id: expense.id,
        costCenterId: expense.costCenterId,
        categoryId: expense.categoryId,
        amount: expense.amount,
        budgetType: expense.budgetType,
        moneySource: expense.moneySource,
        date: expense.date,
        remarks: expense.remarks,
        isSettled: false, // Mark as unsettled
        settledAgainstAdvance: false, // Clear out the advance flag
      );
      
      await FirestoreService().updateExpense(updated, previousData: expense);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close details dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Unsettled!')));
      }
    } catch (e) {
      debugPrint('Error unsettling expense: $e');
    }
  }

  void _confirmDelete(BuildContext context, dynamic item, String type) {
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
              // Pass the full object to log it for undo
              if (type == 'Expense') await service.deleteExpense(item);
              else if (type == 'Donation') await service.deleteDonation(item);
              else if (type == 'Transfer') await service.deleteFundTransfer(item);
              else if (type == 'Adjustment') await service.deletePersonalAdjustment(item);
              
              if (context.mounted) {
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Close details dialog
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
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
