import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../widgets/balance_card.dart';
import '../models/expense.dart';
import '../models/donation.dart';
import '../models/fund_transfer.dart';
import '../models/personal_adjustment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'add_expense_screen.dart';
import 'add_donation_screen.dart';
import 'add_adjustment_screen.dart';
import 'add_center_adjustment_screen.dart';
import 'add_transfer_screen.dart';
import '../models/cost_center_adjustment.dart';
import 'transaction_history_screen.dart';
import '../services/update_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountingProvider>(
      builder: (context, provider, child) {
        final activeCenter = provider.activeCostCenter;
        
        return Scaffold(
          drawer: _buildDrawer(context),
          appBar: AppBar(
            title: null, // Removed "Personal Dashboard V2" title as requested
            actions: [
              if (_selectedIndex == 0 && provider.costCenters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DropdownButton<String>(
                    value: provider.activeCostCenterId,
                    underline: const SizedBox(),
                    dropdownColor: Colors.teal.shade900,
                    icon: const Icon(Icons.business, color: Colors.white),
                    onChanged: (val) {
                      if (val != null) provider.setActiveCostCenter(val);
                    },
                    items: provider.costCenters.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 14, color: Colors.white)),
                      );
                    }).toList(),
                  ),
                ),
              IconButton(
                icon: provider.isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                  : const Icon(Icons.sync, color: Colors.tealAccent),
                onPressed: () => provider.refreshData(),
                tooltip: 'Sync Data',
              ),
            ],
          ),
          body: _selectedIndex == 0 
              ? _buildCostCenterView(context, provider) 
              : _buildPersonalView(context, provider),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: Colors.tealAccent,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance),
                label: 'Project',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Personal',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddMenu(context),
            backgroundColor: Colors.teal.shade700,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildCostCenterView(BuildContext context, AccountingProvider provider) {
    final activeCenter = provider.activeCostCenter;
    if (activeCenter == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No Cost Center found.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/manage-cost-centers'),
              child: const Text('Add Cost Center'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.tealAccent,
      backgroundColor: Colors.teal.shade900,
      onRefresh: () => provider.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        'Cost Center : ${activeCenter.name}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.tealAccent),
                      ),
                      Text(
                        'Last Updated: ${DateFormat('HH:mm:ss').format(provider.lastSync)}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (provider.isSyncing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Syncing...', style: TextStyle(fontSize: 10, color: Colors.tealAccent)),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
          
          const Text('COST CENTER OVERVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 8),

          const SizedBox(height: 16),
          
          // Cost Center Reconciliation Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Cash/Bank', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.receipt_long, color: Colors.blueAccent, size: 20),
                          onPressed: () => Navigator.pushNamed(context, '/ledger', arguments: 'ALL_CENTER'),
                          tooltip: 'Full Statement',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.only(right: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.account_balance, color: Colors.blueAccent, size: 20),
                          onPressed: () => _showUpdateCostCenterRealBalanceDialog(context, provider),
                          tooltip: 'Set Actual Center Cash',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '₹${provider.costCenterBudgetBalance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReconcileStat('Actual (Bank/Cash)', provider.costCenterRealBalance, Colors.white),
                    _buildReconcileStat(
                      'Gap', 
                      provider.costCenterDiscrepancy, 
                      provider.costCenterDiscrepancy == 0 ? Colors.greenAccent : (provider.costCenterDiscrepancy > 0 ? Colors.orangeAccent : Colors.redAccent)
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BalanceCard(
                  title: 'PME Balance',
                  amount: provider.pmeBalance,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.pushNamed(context, '/ledger', arguments: 'PME'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BalanceCard(
                  title: 'OTE Balance',
                  amount: provider.oteBalance,
                  color: Colors.blueAccent,
                  onTap: () => Navigator.pushNamed(context, '/ledger', arguments: 'OTE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BalanceCard(
                  title: 'Advance Unsettled',
                  amount: provider.advanceUnsettled,
                  color: Colors.purpleAccent,
                  onTap: () => Navigator.pushNamed(context, '/ledger', arguments: 'ADVANCE'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: BalanceCard(
                    title: 'Wallet Balance',
                    amount: provider.walletBalance,
                    color: Colors.deepOrangeAccent,
                    onTap: () => Navigator.pushNamed(context, '/ledger', arguments: 'WALLET'),
                  ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),

          const SizedBox(height: 24),
          const Text(
            'Project Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: _ActionCard(
                        icon: Icons.payment,
                        color: Colors.redAccent,
                        label: 'Spend',
                        onTap: () => _showHistoryPopup(context, 'Direct Spend History', provider.expenses.where((e) => e.moneySource != MoneySource.PERSONAL).toList(), 'Expense', const AddExpenseScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: _ActionCard(
                        icon: Icons.volunteer_activism,
                        color: Colors.greenAccent,
                        label: 'Donation',
                        onTap: () => _showHistoryPopup(context, 'Donation History', provider.donations, 'Donation', const AddDonationScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Advance & Internal Transfer
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: _ActionCard(
                        icon: Icons.person_add_alt_1, // Changed icon to indicate personal
                        color: Colors.blueAccent,
                        label: 'Advance (Per)',
                        onTap: () => _showHistoryPopup(
                            context, 
                            'Personal Advance History', 
                            provider.transfers.where((t) => t.costCenterId == activeCenter.id && t.type == TransferType.TO_PERSONAL && t.fromCategoryId == null && t.toCategoryId == null).toList(), 
                            'Transfer', 
                            const AddTransferScreen(initialType: TransferType.TO_PERSONAL)
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: _ActionCard(
                        icon: Icons.sync_alt,
                        color: Colors.orangeAccent,
                        label: 'Inter-Transfer',
                        onTap: () => _showHistoryPopup(
                            context,
                            'Internal Transfer History', 
                            provider.transfers.where((t) => t.costCenterId == activeCenter.id && t.type == TransferType.CATEGORY_TO_CATEGORY).toList(), 
                            'Internal Transfer', // Changed type string to distinguish in popup
                            const AddTransferScreen(initialType: TransferType.CATEGORY_TO_CATEGORY)
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Categories & Reports
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: _ActionCard(
                        icon: Icons.settings,
                        color: Colors.purpleAccent,
                        label: 'Categories',
                        onTap: () => Navigator.pushNamed(context, '/manage-categories'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 70,
                      child: _ActionCard(
                        icon: Icons.bar_chart,
                        color: Colors.pinkAccent,
                        label: 'Reports',
                        onTap: () => Navigator.pushNamed(context, '/reports'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
     ),
    );
  }

  Widget _buildPersonalView(BuildContext context, AccountingProvider provider) {
    // Helper for names




    return RefreshIndicator(
      color: Colors.tealAccent,
      backgroundColor: Colors.teal.shade900,
      onRefresh: () => provider.refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Dashboard',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                    ),
                    Text(
                      'Last Updated: ${DateFormat('HH:mm:ss').format(provider.lastSync)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                if (provider.isSyncing)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal.shade900, Colors.teal.shade700]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expected Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet, color: Colors.tealAccent, size: 20),
                      onPressed: () => _showUpdateRealBalanceDialog(context, provider),
                      tooltip: 'Set Actual Cash',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                Text(
                  '₹${provider.personalBalance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReconcileStat('Actual Balance', provider.realBalance, Colors.white),
                    _buildReconcileStat(
                      'Gap', 
                      provider.personalDiscrepancy, 
                      provider.personalDiscrepancy == 0 ? Colors.greenAccent : (provider.personalDiscrepancy > 0 ? Colors.orangeAccent : Colors.redAccent)
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('PERSONAL QUICK ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              _ActionCard(
                icon: Icons.account_balance,
                color: Colors.tealAccent,
                label: 'Personal Adj',
                onTap: () => _showHistoryPopup(context, 'Personal Advance History', provider.adjustments, 'PersonalAdjustment', const AddAdjustmentScreen()),
              ),
              _ActionCard(
                icon: Icons.swap_horiz,
                color: Colors.blueAccent,
                label: 'Adv Received',
                onTap: () => _showHistoryPopup(
                  context, 
                  'Advance Received History', 
                  provider.transfers.where((t) => t.costCenterId == provider.activeCostCenterId && t.type == TransferType.TO_PERSONAL && t.fromCategoryId == null && t.toCategoryId == null).toList(), 
                  'Transfer', 
                  const AddTransferScreen(initialType: TransferType.TO_PERSONAL)
                ),
              ),
              _ActionCard(
                icon: Icons.savings,
                color: Colors.orangeAccent,
                label: 'Fixed Bal',
                onTap: () => Navigator.pushNamed(context, '/fixed-amounts'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
        ],
      ),
     ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.teal.shade900),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.tealAccent, size: 48),
                SizedBox(height: 12),
                Text('Cost Center APP', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.corporate_fare_outlined, color: Colors.tealAccent),
            title: const Text('Manage Cost Centers'),
            onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/manage-cost-centers'); },
          ),
          Consumer<AccountingProvider>(
            builder: (context, provider, _) {
              return SwitchListTile(
                title: const Text('Dark Mode'),
                secondary: Icon(provider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.purpleAccent),
                value: provider.isDarkMode,
                onChanged: (val) => provider.toggleTheme(),
              );
            }
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign Out'),
            onTap: () async {
              Navigator.pop(context);
              await AuthService().signOut();
            },
          ),
        ],
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
            child: Text('Create New Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (_selectedIndex == 0) ...[
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.redAccent),
              title: const Text('Direct Spend (Expense)'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddExpenseScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism, color: Colors.greenAccent),
              title: const Text('Donation'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddDonationScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.orangeAccent),
              title: const Text('Cost Center Adjustment'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddCenterAdjustmentScreen()); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
              title: const Text('Take Advance (Transfer)'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddTransferScreen()); },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.tealAccent),
              title: const Text('Personal Expenses Entry'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddExpenseScreen(defaultSource: MoneySource.PERSONAL)); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
              title: const Text('Record Advance Received'),
              onTap: () { Navigator.pop(context); _showForm(context, const AddTransferScreen()); },
            ),
          ],
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

  void _showHistoryPopup(BuildContext context, String title, List<dynamic> items, String type, Widget addScreen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: title,
          items: items,
          type: type,
          addScreen: addScreen,
          showEntryDetails: _showEntryDetails,
        ),
      ),
    );
  }

  void _showEntryDetails(BuildContext context, dynamic item, String type) {
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

    String? categoryLine;
    List<Widget> extraDetails = [];

    if (item is Expense) {
      categoryLine = getCatName(item.categoryId);
      extraDetails = [
        const SizedBox(height: 8),
        Text('Money Source: ${item.moneySource.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 4),
        Text('Budget Type: ${item.budgetType.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
      ];
    } else if (item is Donation) {
      categoryLine = getCatName(item.budgetCategoryId);
      extraDetails = [
        const SizedBox(height: 8),
        Text('Mode: ${item.mode.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
      ];
    } else if (item is FundTransfer) {
      if (item.type == TransferType.CATEGORY_TO_CATEGORY) {
        extraDetails = [
          const SizedBox(height: 8),
          const Text('TRANSFER PATH:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          Text('FROM: ${getCatName(item.fromCategoryId)}', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
          const SizedBox(height: 4),
          Text('TO: ${getCatName(item.toCategoryId)}', style: const TextStyle(fontSize: 14)),
        ];
      } else {
        extraDetails = [
          const SizedBox(height: 8),
          const Text('TYPE: Personal Advance', style: TextStyle(fontSize: 14, color: Colors.blueAccent)),
        ];
      }
    }

    String? costCenterName;
    if (type != 'Adjustment' || item is CostCenterAdjustment) {
      try {
        final cc = provider.costCenters.where((c) => c.id == item.costCenterId).toList();
        if (cc.isNotEmpty) costCenterName = cc.first.name;
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type == 'Internal Transfer' ? 'Fund Transfer' : type} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Remarks: ${item.remarks}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            const SizedBox(height: 8),
            Text('Amount: ₹${item.amount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
            const SizedBox(height: 4),
            Text('Date: ${DateFormat('yyyy-MM-dd').format(item.date)}', style: const TextStyle(fontSize: 15)),
            if (categoryLine != null) ...[
              const SizedBox(height: 4),
              Text('Category: $categoryLine', style: const TextStyle(fontSize: 15)),
            ],
            if (costCenterName != null) ...[
              const SizedBox(height: 4),
              Text('Cost Center: $costCenterName', style: const TextStyle(fontSize: 15)),
            ],
            ...extraDetails,
            if (type == 'Adjustment') ...[
              const SizedBox(height: 8),
              Text('Adjustment Type: ${item.type.toString().split('.').last}', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(item is PersonalAdjustment ? 'Personal Account' : 'Cost Center Budget', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'Expense') {
                _showForm(context, AddExpenseScreen(expenseToEdit: item as Expense));
              } else if (type == 'Donation') {
                _showForm(context, AddDonationScreen(donationToEdit: item as Donation));
              } else if (type == 'Adjustment') {
                if (item is PersonalAdjustment) {
                  _showForm(context, AddAdjustmentScreen(adjustmentToEdit: item));
                } else {
                  _showForm(context, AddCenterAdjustmentScreen(adjustmentToEdit: item as CostCenterAdjustment));
                }
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
              if (item is Expense) {
                await service.deleteExpense(item.id);
              } else if (item is Donation) {
                await service.deleteDonation(item.id);
              } else if (item is FundTransfer) {
                await service.deleteFundTransfer(item.id);
              } else if (item is PersonalAdjustment) {
                await service.deletePersonalAdjustment(item.id);
              } else if (item is CostCenterAdjustment) {
                await service.deleteCostCenterAdjustment(item.id);
              }
              
              if (ctx.mounted) {
                Navigator.pop(ctx); // Close confirmation
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildReconcileStat(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          '₹${amount.toStringAsFixed(2)}', 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ],
    );
  }

  void _showUpdateRealBalanceDialog(BuildContext context, AccountingProvider provider) {
    final controller = TextEditingController(text: provider.realBalance.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconcile Actual Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the exact real-world balance you have in your pocket/bank currently.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual Balance Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              final amt = double.tryParse(text);
              if (amt == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount'))
                );
                return;
              }

              try {
                await provider.updateRealBalance(amt);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Balance updated successfully'))
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving balance: $e'))
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUpdateCostCenterRealBalanceDialog(BuildContext context, AccountingProvider provider) {
    final controller = TextEditingController(text: provider.costCenterRealBalance.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reconcile Cost Center Cash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the total ACTUAL cash/bank balance currently held for this Cost Center.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Actual Bank/Cash Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              final amt = double.tryParse(text);
              if (amt == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount'))
                );
                return;
              }

              try {
                await provider.updateCostCenterRealBalance(amt);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cost Center balance updated'))
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'))
                  );
                }
              }
            },
            child: const Text('Save'),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
