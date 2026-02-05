import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../models/donation.dart';
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
  
  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedExpenseIds.contains(id)) {
        _selectedExpenseIds.remove(id);
      } else {
        _selectedExpenseIds.add(id);
      }
    });
  }

  Future<void> _settleSelectedExpenses(List<Expense> allPending) async {
    if (_selectedExpenseIds.isEmpty) return;

    final service = FirestoreService();
    int count = 0;
    
    for (var id in _selectedExpenseIds) {
      try {
        final expense = allPending.firstWhere((e) => e.id == id);
        final updated = Expense(
          id: expense.id,
          costCenterId: expense.costCenterId,
          categoryId: expense.categoryId,
          amount: expense.amount,
          budgetType: expense.budgetType,
          moneySource: expense.moneySource,
          date: expense.date,
          remarks: expense.remarks,
          isSettled: true,
        );
        await service.updateExpense(updated);
        count++;
      } catch (e) {
        debugPrint('Error settling expense $id: $e');
      }
    }
    
    setState(() {
      _selectedExpenseIds.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count Expenses Settled!')));
    }
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

        // Add Transfers (Advances)
        for (var t in provider.transfers.where((t) => t.type == TransferType.TO_PERSONAL && t.fromCategoryId == null && t.toCategoryId == null)) {
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
            'searchBlob': 'advance from $ccName ${t.remarks} ${t.amount}'.toLowerCase(),
          });
        }

        // Add Settled Expenses
        for (var e in provider.allExpenses.where((x) => x.moneySource == MoneySource.PERSONAL && x.isSettled)) {
          final ccName = _getCostCenterName(provider, e.costCenterId);
          final catPath = _getCategoryPath(provider, e.categoryId);
          historyEntries.add({
            'title': e.remarks,
            'subtitle': '$ccName -> $catPath',
            'dateLine': DateFormat('dd MMM yyyy').format(e.date),
            'amount': -e.amount,
            'date': e.date,
            'type': 'Expense',
            'color': Colors.redAccent,
            'item': e,
            'searchBlob': '${e.remarks} $ccName $catPath ${e.amount}'.toLowerCase(),
          });
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

        pendingExpenses.sort((a, b) => b.date.compareTo(a.date));
        historyEntries.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        // Assign unique keys for history selection
        for (int i = 0; i < historyEntries.length; i++) {
          final item = historyEntries[i]['item'];
          historyEntries[i]['uniqueKey'] = item.id;
        }

        double pendingSum = pendingExpenses
            .where((e) => _selectedExpenseIds.contains(e.id))
            .fold(0.0, (sum, e) => sum + e.amount);
        
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
                      hintText: 'Search...',
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
                      Text(
                        '₹${provider.personalBalance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: provider.isDarkMode ? Colors.white : Colors.teal.shade900),
                      ),
                      Text('Balance includes all advances and unssettled expenses.', style: TextStyle(fontSize: 12, color: provider.isDarkMode ? Colors.grey : Colors.grey.shade700)),
                      if (hasSelection) ...[
                        Divider(height: 24, color: provider.isDarkMode ? Colors.white24 : Colors.teal.withOpacity(0.3)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Selected Sum:', style: TextStyle(fontSize: 14, color: provider.isDarkMode ? Colors.tealAccent : Colors.teal.shade800, fontWeight: FontWeight.bold)),
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
                      _buildPendingList(context, pendingExpenses),
                      
                      // Tab 2: History
                      _buildHistoryList(historyEntries),
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
    
    // Group
    final Map<String, List<Expense>> grouped = {};
    for (var e in expenses) {
      if (!grouped.containsKey(e.costCenterId)) {
        grouped[e.costCenterId] = [];
      }
      grouped[e.costCenterId]!.add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final costCenterId = grouped.keys.elementAt(index);
        final centerExpenses = grouped[costCenterId]!;
        final centerName = _getCostCenterName(provider, costCenterId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                centerName,
                style: TextStyle(color: provider.isDarkMode ? Colors.teal.shade200 : Colors.teal.shade800, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ),
            ...centerExpenses.map((e) {
              final isSelected = _selectedExpenseIds.contains(e.id);
              final catPath = _getCategoryPath(provider, e.categoryId);

              // Bank Statement Style Row
              return InkWell(
                onTap: () => _toggleSelection(e.id),
                child: Container(
                  color: isSelected ? Colors.teal.withOpacity(0.15) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) => _toggleSelection(e.id),
                        activeColor: Colors.tealAccent,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM').format(e.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(e.remarks, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: provider.isDarkMode ? null : Colors.black87)),
                            const SizedBox(height: 2),
                            Text('$centerName -> $catPath', style: TextStyle(fontSize: 12, color: provider.isDarkMode ? Colors.white70 : Colors.black54)),
                          ],
                        ),
                      ),
                      Text(
                        '-${e.amount.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            Divider(color: provider.isDarkMode ? null : Colors.grey.shade300),
          ],
        );
      },
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
          separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16, color: provider.isDarkMode ? null : Colors.grey.shade300),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final amount = entry['amount'] as double;
            final isPositive = amount > 0;
            final title = entry['title'] as String;
            final subtitle = entry['subtitle'] as String; // Context path
            final dateLine = entry['dateLine'] as String;
            final meta = entry['meta']; // For Transfers, remarks are here

            final String uniqueId = entry['uniqueKey'];
            final bool isSelected = _selectedHistoryIds.contains(uniqueId);

            return InkWell(
              onTap: () => _showEntryDetails(context, entry['item'], entry['type']),
              child: Container(
                color: isSelected ? Colors.teal.withOpacity(0.1) : null,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Checkbox for summing
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedHistoryIds.add(uniqueId);
                            } else {
                              _selectedHistoryIds.remove(uniqueId);
                            }
                          });
                        },
                        activeColor: Colors.tealAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Icon Circle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (entry['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                        color: entry['color'],
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
                            dateLine,
                            style: TextStyle(color: provider.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: provider.isDarkMode ? null : Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle.isNotEmpty) 
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle,
                                style: TextStyle(color: provider.isDarkMode ? Colors.white60 : Colors.black54, fontSize: 12),
                              ),
                            ),
                          if (meta != null && meta.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                meta,
                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: provider.isDarkMode ? Colors.white70 : Colors.black54),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : '-'}${amount.abs().toStringAsFixed(0)}',
                          style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (entry['type'] == 'Expense')
                           Padding(
                             padding: const EdgeInsets.only(top: 4),
                             child: Text('Settled', style: TextStyle(fontSize: 10, color: provider.isDarkMode ? Colors.grey : Colors.grey.shade600)),
                           ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
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
            onPressed: () => _confirmDelete(context, item.id, type),
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
      );
      
      await FirestoreService().updateExpense(updated);
      
      if (context.mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Unsettled!')));
      }
    } catch (e) {
      debugPrint('Error unsettling expense: $e');
    }
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
              else if (type == 'Adjustment') await service.deletePersonalAdjustment(entryId);
              
              if (ctx.mounted) {
                Navigator.pop(ctx); 
              }
              if (context.mounted) {
                Navigator.pop(context); 
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
