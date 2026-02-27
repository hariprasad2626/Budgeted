import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/cost_center.dart';
import '../models/budget_category.dart';
import '../models/budget_allocation.dart';
import '../models/donation.dart';
import '../models/fund_transfer.dart';
import '../models/expense.dart';
import '../models/personal_adjustment.dart';
import '../models/cost_center_adjustment.dart';
import '../models/fixed_amount.dart';
import '../models/budget_period.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';

class AccountingProvider with ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  String? _activeCostCenterId;
  List<CostCenter> _costCenters = [];

  List<BudgetCategory> _categories = [];
  List<BudgetAllocation> _allocations = [];
  List<Donation> _donations = [];
  List<Expense> _expenses = [];
  
  // Global data (shared across cost centers)
  List<FundTransfer> _transfers = [];
  List<PersonalAdjustment> _adjustments = [];
  List<CostCenterAdjustment> _centerAdjustments = [];
  List<Expense> _allExpenses = [];
  List<FixedAmount> _fixedAmounts = [];
  List<BudgetPeriod> _budgetPeriods = [];
  double _realBalance = 0;
  double _costCenterRealBalance = 0;
  DateTime _lastSync = DateTime.now();
  bool _isSyncing = false;
  static const String appVersion = '1.1.17+71';

  List<CostCenter> get costCenters => _costCenters;
  String? get activeCostCenterId => _activeCostCenterId;
  DateTime get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }
  
  CostCenter? get activeCostCenter => _costCenters.isEmpty 
      ? null 
      : _costCenters.firstWhere((c) => c.id == _activeCostCenterId, orElse: () => _costCenters.first);

  List<BudgetCategory> get categories => _categories;
  List<BudgetAllocation> get allocations => _allocations;
  List<Donation> get donations => _donations;
  List<Expense> get expenses => _expenses;
  List<FundTransfer> get transfers => _transfers;
  List<PersonalAdjustment> get adjustments => _adjustments;
  List<CostCenterAdjustment> get centerAdjustments => _centerAdjustments;
  List<Expense> get allExpenses => _allExpenses;
  List<FixedAmount> get fixedAmounts => _fixedAmounts;
  List<BudgetPeriod> get budgetPeriods => _budgetPeriods;
  double get realBalance => _realBalance;
  double get costCenterRealBalance => _costCenterRealBalance;
  
  double get personalDiscrepancy => _realBalance - personalBalance;
  double get costCenterDiscrepancy => _costCenterRealBalance - costCenterBudgetBalance;

  // Stream subscriptions
  StreamSubscription? _catSub;
  StreamSubscription? _allocSub;
  StreamSubscription? _donSub;
  StreamSubscription? _expSub;
  StreamSubscription? _adjSub;
  StreamSubscription? _fixedSub;
  StreamSubscription? _realSub;
  StreamSubscription? _centerRealSub;
  StreamSubscription? _budgetPeriodSub;
  // Global stream subscriptions
  StreamSubscription? _transferSub;
  StreamSubscription? _personalAdjSub;

  AccountingProvider() {
    _loadCache().then((_) {
      _initGlobal();
      _initCostCenters();
      loadTheme();
    });
  }

  Future<void> _loadCache() async {
    _activeCostCenterId = await CacheService.loadValue('activeCostCenterId');
    final realBalanceVal = await CacheService.loadValue('realBalance');
    if (realBalanceVal != null) _realBalance = double.tryParse(realBalanceVal) ?? 0;
    if (_activeCostCenterId != null) {
      final centerRealValue = await CacheService.loadValue('centerRealBalance_$_activeCostCenterId');
      if (centerRealValue != null) _costCenterRealBalance = double.tryParse(centerRealValue) ?? 0;
      _subscribeToCenterData(_activeCostCenterId!);
    }
    notifyListeners();
  }

  void _initGlobal() {
    _transferSub?.cancel();
    _transferSub = _service.getFundTransfers().listen((data) {
      _transfers = data;
      CacheService.saveList('transfers', data);
      notifyListeners();
    });
    
    _personalAdjSub?.cancel();
    _personalAdjSub = _service.getPersonalAdjustments().listen((data) {
      _adjustments = data;
      CacheService.saveList('adjustments', data);
      notifyListeners();
    });
    
    _expSub?.cancel();
    _expSub = _service.getExpenses().listen((data) {
      _allExpenses = data;
      CacheService.saveList('allExpenses', data);
      if (_activeCostCenterId != null) {
        _expenses = _allExpenses.where((e) => e.costCenterId == _activeCostCenterId).toList();
      }
      notifyListeners();
    });

    _fixedSub = _service.getFixedAmounts().listen((data) {
      _fixedAmounts = data;
      CacheService.saveList('fixedAmounts', data);
      notifyListeners();
    });
    _realSub = _service.getRealBalance().listen((data) {
      _realBalance = data;
      CacheService.saveValue('realBalance', data);
      notifyListeners();
    });
  }

  void _initCostCenters() {
    _service.getCostCenters().listen((data) {
      _costCenters = data;
      CacheService.saveList('costCenters', data);
      if (_activeCostCenterId == null && _costCenters.isNotEmpty) {
        setActiveCostCenter(_costCenters.first.id);
      }
      notifyListeners();
    });
  }

  void setActiveCostCenter(String id) {
    _activeCostCenterId = id;
    CacheService.saveValue('activeCostCenterId', id);
    _subscribeToCenterData(id);
    if (_allExpenses.isNotEmpty) {
      _expenses = _allExpenses.where((e) => e.costCenterId == id).toList();
    }
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isSyncing = true;
    _lastSync = DateTime.now();
    notifyListeners();
    _initGlobal();
    _initCostCenters();
    if (_activeCostCenterId != null) {
      _subscribeToCenterData(_activeCostCenterId!);
    }
    await Future.delayed(const Duration(seconds: 2));
    _isSyncing = false;
    notifyListeners();
  }

  void _subscribeToCenterData(String id) {
    _catSub?.cancel();
    _allocSub?.cancel();
    _donSub?.cancel();
    _adjSub?.cancel();
    _centerRealSub?.cancel();
    _budgetPeriodSub?.cancel();

    _catSub = _service.getCategories(id).listen((data) {
      _categories = data;
      CacheService.saveList('categories_$id', data);
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _allocSub = _service.getAllocations(id).listen((data) {
      _allocations = data;
      CacheService.saveList('allocations_$id', data);
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _donSub = _service.getDonations(id).listen((data) {
      _donations = data;
      CacheService.saveList('donations_$id', data);
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _adjSub = _service.getCostCenterAdjustments(id).listen((data) {
      _centerAdjustments = data;
      CacheService.saveList('centerAdjustments_$id', data);
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _centerRealSub = _service.getCostCenterRealBalance(id).listen((data) {
      _costCenterRealBalance = data;
      CacheService.saveValue('centerRealBalance_$id', data);
      notifyListeners();
    });
    _budgetPeriodSub = _service.getBudgetPeriods(id).listen((data) {
      _budgetPeriods = data;
      CacheService.saveList('budgetPeriods_$id', data);
      _lastSync = DateTime.now();
      notifyListeners();
    });
  }

  // --- Balance Calculations ---

  double get personalBalance {
    double ccTransfers = _transfers
        .where((t) => t.type == TransferType.TO_PERSONAL)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    double ccExpenses = _allExpenses
        .where((e) => e.moneySource == MoneySource.PERSONAL)
        .fold(0.0, (sum, e) => sum + e.amount);

    double ccSettled = _allExpenses
        .where((e) => e.moneySource == MoneySource.PERSONAL && e.isSettled && !e.settledAgainstAdvance)
        .fold(0.0, (sum, e) => sum + e.amount);

    double totalBalance = ccTransfers + ccSettled - ccExpenses;

    double debits = _adjustments.where((a) => a.type == AdjustmentType.DEBIT).fold(0, (sum, a) => sum + a.amount);
    double credits = _adjustments.where((a) => a.type == AdjustmentType.CREDIT).fold(0, (sum, a) => sum + a.amount);
    double fixedTotal = _fixedAmounts.fold(0, (sum, item) => sum + item.amount);

    return totalBalance - debits + credits + fixedTotal;
  }

  double _getAdjustmentTotal(BudgetType type) {
    double debits = _centerAdjustments
        .where((a) => a.budgetType == type && a.type == AdjustmentType.DEBIT)
        .fold(0, (sum, a) => sum + a.amount);
    double credits = _centerAdjustments
        .where((a) => a.budgetType == type && a.type == AdjustmentType.CREDIT)
        .fold(0, (sum, a) => sum + a.amount);
    return credits - debits;
  }

  double get categoriesBalance {
    return _categories
        .where((c) => c.isActive)
        .fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['remaining']!);
  }

  double get pmeBalance {
    return _categories
        .where((c) => c.budgetType == BudgetType.PME && c.isActive)
        .fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['remaining']!);
  }

  double get pmeEarmarkedLimit {
    return _categories
        .where((c) => c.budgetType == BudgetType.PME && c.isActive)
        .fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['total_limit']!);
  }

  double get oteBalance {
    return _categories
        .where((c) => c.budgetType == BudgetType.OTE && c.isActive)
        .fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['remaining']!);
  }

  double get oteEarmarkedLimit {
    return _categories
        .where((c) => c.budgetType == BudgetType.OTE && c.isActive)
        .fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['total_limit']!);
  }

  BudgetType getBudgetTypeForCategory(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId).budgetType;
    } catch (_) {
      return BudgetType.OTE;
    }
  }

  double get totalPmeBudgeted {
    double total = 0;
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
       for (var month in period.getAllMonths()) {
        if (isMonthInPastOrCurrent(month)) {
          total += period.getPmeForMonth(month);
        }
      }
    }
    return total;
  }

  double get totalOteBudgeted {
    return _budgetPeriods.where((p) => p.isActive).fold(0.0, (sum, p) => sum + p.oteAmount);
  }

  double get pmeSpent {
    return _expenses
        .where((e) => e.budgetType == BudgetType.PME && (e.moneySource != MoneySource.PERSONAL || (e.isSettled && !e.settledAgainstAdvance)))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get oteSpent {
    return _expenses
        .where((e) => e.budgetType == BudgetType.OTE && (e.moneySource != MoneySource.PERSONAL || (e.isSettled && !e.settledAgainstAdvance)))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get pmeSurplus {
     // Baseline Credit - Earmarked Targets - Uncategorized PME Spends + Global Adj
     double totalPmeEarmarked = _categories
        .where((c) => c.budgetType == BudgetType.PME && c.isActive)
        .fold(0.0, (sum, c) => sum + (c.targetAmount * getElapsedMonthsForCategory(c)));
     
     double pmeUncategorizedSpent = _expenses
        .where((e) => e.budgetType == BudgetType.PME && e.categoryId == '' && (e.moneySource != MoneySource.PERSONAL || (e.isSettled && !e.settledAgainstAdvance)))
        .fold(0.0, (sum, e) => sum + e.amount);
     
     double globalAdj = _centerAdjustments
        .where((a) => a.budgetType == BudgetType.PME && a.categoryId == null)
        .fold(0.0, (sum, a) => sum + (a.type == AdjustmentType.CREDIT ? a.amount : -a.amount));
     
     return totalPmeBudgeted - totalPmeEarmarked - pmeUncategorizedSpent + globalAdj;
  }

  double get oteSurplus {
     double totalOteEarmarked = _categories
        .where((c) => c.budgetType == BudgetType.OTE && c.isActive)
        .fold(0.0, (sum, c) => sum + c.targetAmount);

     double oteUncategorizedSpent = _expenses
        .where((e) => e.budgetType == BudgetType.OTE && e.categoryId == '' && (e.moneySource != MoneySource.PERSONAL || (e.isSettled && !e.settledAgainstAdvance)))
        .fold(0.0, (sum, e) => sum + e.amount);

     double globalAdj = _centerAdjustments
        .where((a) => a.budgetType == BudgetType.OTE && a.categoryId == null)
        .fold(0.0, (sum, a) => sum + (a.type == AdjustmentType.CREDIT ? a.amount : -a.amount));

     return totalOteBudgeted - totalOteEarmarked - oteUncategorizedSpent + globalAdj;
  }



  double get costCenterBudgetBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    double totalBaseline = 0;
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      for (var month in period.getAllMonths()) {
        if (isMonthInPastOrCurrent(month)) {
          totalBaseline += period.getPmeForMonth(month);
        }
      }
      totalBaseline += period.oteAmount;
    }

    double totalDonations = _donations.fold(0.0, (sum, d) => sum + d.amount);

    // Total Expenses (Non-personal + Reimbursements)
    double totalExpenses = _expenses
        .where((e) => e.moneySource != MoneySource.PERSONAL || (e.isSettled && !e.settledAgainstAdvance))
        .fold(0.0, (sum, e) => sum + e.amount);

    double adjustments = _getAdjustmentTotal(BudgetType.PME) + _getAdjustmentTotal(BudgetType.OTE);

    double totalAdvancesFromCenter = _transfers
        .where((t) => t.costCenterId == center.id && t.type == TransferType.TO_PERSONAL)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    return totalBaseline + totalDonations - totalExpenses + adjustments - totalAdvancesFromCenter;
  }

  double get advanceUnsettled {
    final center = activeCostCenter;
    if (center == null) return 0;

    double totalAdvances = _transfers
        .where((t) => t.costCenterId == center.id && t.type == TransferType.TO_PERSONAL)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    double settledAgainstAdvance = _expenses
        .where((e) => e.moneySource == MoneySource.PERSONAL && e.isSettled && e.settledAgainstAdvance)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    
    double net = totalAdvances - settledAgainstAdvance;
    return net < 0 ? 0 : net;
  }

  double get walletBalance {
    final center = activeCostCenter;
    if (center == null) return 0;
    double catBalances = _categories.where((c) => c.isActive).fold(0.0, (sum, cat) => sum + getCategoryStatus(cat)['remaining']!);
    return costCenterBudgetBalance - catBalances;
  }

  Map<String, double> getCategoryStatus(BudgetCategory cat) {
    double budget = cat.targetAmount;
    if (cat.budgetType == BudgetType.PME) {
      budget = budget * getElapsedMonthsForCategory(cat);
    }

    final donations = _donations
        .where((d) => d.mode == DonationMode.MERGE_TO_BUDGET && d.budgetCategoryId == cat.id)
        .fold(0.0, (sum, d) => sum + d.amount);
    
    final spent = _expenses
        .where((e) => e.categoryId == cat.id && (e.moneySource != MoneySource.PERSONAL || e.isSettled))
        .fold(0.0, (sum, e) => sum + e.amount);

    double adjustments = _centerAdjustments
        .where((a) => a.categoryId == cat.id)
        .fold(0, (sum, a) => sum + (a.type == AdjustmentType.CREDIT ? a.amount : -a.amount));

    // Visible Transfers
    double outgoingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId == cat.id)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    double incomingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId == cat.id)
        .fold(0.0, (sum, t) => sum + t.amount);

    return {
      'budget': budget,
      'donations': donations,
      'spent': spent,
      'adjustments': adjustments,
      'transfers': incomingTransfers - outgoingTransfers,
      'total_limit': budget + donations + adjustments + incomingTransfers - outgoingTransfers,
      'remaining': budget + donations - spent + adjustments + incomingTransfers - outgoingTransfers,
    };
  }

  bool isMonthInPastOrCurrent(String month) {
    try {
      final now = DateTime.now();
      final currentMonthVal = now.year * 100 + now.month;
      final parts = month.split('-');
      final monthVal = int.parse(parts[0]) * 100 + int.parse(parts[1]);
      return monthVal <= currentMonthVal;
    } catch (_) {
      return false;
    }
  }

  bool isMonthOnOrAfterCategoryCreation(String month, DateTime createdAt) {
    try {
      final parts = month.split('-');
      final monthVal = int.parse(parts[0]) * 100 + int.parse(parts[1]);
      final createdVal = createdAt.year * 100 + createdAt.month;
      return monthVal >= createdVal;
    } catch (_) {
      return false;
    }
  }

  int getElapsedMonthsForCategory(BudgetCategory cat) {
    final Set<String> elapsedMonths = {};
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      for (var month in period.getAllMonths()) {
        if (isMonthInPastOrCurrent(month) && isMonthOnOrAfterCategoryCreation(month, cat.createdAt)) {
          elapsedMonths.add(month);
        }
      }
    }
    return elapsedMonths.length;
  }

  @override
  void dispose() {
    _catSub?.cancel();
    _allocSub?.cancel();
    _donSub?.cancel();
    _expSub?.cancel();
    _adjSub?.cancel();
    _fixedSub?.cancel();
    _realSub?.cancel();
    _centerRealSub?.cancel();
    _budgetPeriodSub?.cancel();
    super.dispose();
  }

  Future<void> updateRealBalance(double amount) async {
    await _service.updateRealBalance(amount);
  }

  Future<void> updateCostCenterRealBalance(double amount) async {
    if (_activeCostCenterId != null) {
      await _service.updateCostCenterRealBalance(_activeCostCenterId!, amount);
    }
  }

  Future<void> transferBetweenCategoryAndWallet({
    required String categoryId,
    required double amount,
    required bool isToWallet,
    required String remarks,
  }) async {
    if (_activeCostCenterId == null) return;

    if (isToWallet) {
      final cat = _categories.firstWhere((c) => c.id == categoryId, orElse: () => throw Exception('Category not found'));
      final status = getCategoryStatus(cat);
      /* 
      if (status['remaining']! < amount) {
        throw Exception('Insufficient category balance. You can only transfer up to ₹${status['remaining']!.toStringAsFixed(2)} to wallet.');
      }
      */
    }

    final transfer = FundTransfer(
      id: '',
      costCenterId: _activeCostCenterId!,
      amount: amount,
      date: DateTime.now(),
      remarks: remarks,
      type: TransferType.CATEGORY_TO_CATEGORY,
      fromCategoryId: isToWallet ? categoryId : null,
      toCategoryId: isToWallet ? null : categoryId,
    );
    await _service.addFundTransfer(transfer);
  }

  Map<String, Map<String, double>> getMonthlyPerformanceMetrics() {
    final Map<String, Map<String, double>> metrics = {};
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      // Initialize OTE budget in the 'OTE_TOTAL' pseudo-month or just handle it globally?
      // For OTE, we'll store it in a special key or just distribute it.
      // But let's follow the user's need: they want to see the total limit change.
      for (var month in period.getAllMonths()) {
        metrics.putIfAbsent(month, () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
        metrics[month]!['pme_budget'] = (metrics[month]!['pme_budget'] ?? 0) + period.getPmeForMonth(month);
      }
      
      // We'll use 'OTE_GLOBAL' to track OTE budget shifts
      metrics.putIfAbsent('OTE_GLOBAL', () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
      metrics['OTE_GLOBAL']!['ote_budget'] = (metrics['OTE_GLOBAL']!['ote_budget'] ?? 0) + period.oteAmount;
    }

    for (var expense in _expenses) {
      if (expense.moneySource == MoneySource.PERSONAL && !expense.isSettled) continue;
      String month = expense.budgetMonth ?? DateFormat('yyyy-MM').format(expense.date);
      metrics.putIfAbsent(month, () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
      metrics.putIfAbsent('OTE_GLOBAL', () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});

      if (expense.budgetType == BudgetType.PME) {
        metrics[month]!['pme_actual'] = (metrics[month]!['pme_actual'] ?? 0) + expense.amount;
      } else {
        metrics[month]!['ote_actual'] = (metrics[month]!['ote_actual'] ?? 0) + expense.amount;
        metrics['OTE_GLOBAL']!['ote_actual'] = (metrics['OTE_GLOBAL']!['ote_actual'] ?? 0) + expense.amount;
      }
    }

    for (var transfer in _transfers) {
      if (transfer.type == TransferType.CATEGORY_TO_CATEGORY) {
        String? month = transfer.targetMonth;
        
        // Handle PME Shifts (Monthly)
        if (month != null) {
          metrics.putIfAbsent(month, () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
          
          if (transfer.toCategoryId != null) {
            try {
              final toCat = _categories.firstWhere((c) => c.id == transfer.toCategoryId);
              if (toCat.budgetType == BudgetType.PME) {
                metrics[month]!['pme_budget'] = (metrics[month]!['pme_budget'] ?? 0) + transfer.amount;
              }
            } catch (_) {}
          }
          if (transfer.fromCategoryId != null) {
            try {
              final fromCat = _categories.firstWhere((c) => c.id == transfer.fromCategoryId);
              if (fromCat.budgetType == BudgetType.PME) {
                metrics[month]!['pme_budget'] = (metrics[month]!['pme_budget'] ?? 0) - transfer.amount;
              }
            } catch (_) {}
          }
        }

        // Handle OTE Shifts (Global inside metrics)
        metrics.putIfAbsent('OTE_GLOBAL', () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
        
        bool involveOte = false;
        if (transfer.toCategoryId != null) {
          try {
            final toCat = _categories.firstWhere((c) => c.id == transfer.toCategoryId);
            if (toCat.budgetType == BudgetType.OTE) {
              metrics['OTE_GLOBAL']!['ote_budget'] = (metrics['OTE_GLOBAL']!['ote_budget'] ?? 0) + transfer.amount;
              involveOte = true;
            }
          } catch (_) {}
        }
        if (transfer.fromCategoryId != null) {
          try {
            final fromCat = _categories.firstWhere((c) => c.id == transfer.fromCategoryId);
            if (fromCat.budgetType == BudgetType.OTE) {
              metrics['OTE_GLOBAL']!['ote_budget'] = (metrics['OTE_GLOBAL']!['ote_budget'] ?? 0) - transfer.amount;
              involveOte = true;
            }
          } catch (_) {}
        }

        // SPECIAL CASE: Wallet to Category shifts the Global Limit if it's new money injection
        // If fromCategoryId is null (Wallet) and to is OTE, it increases OTE limit.
        // If toCategoryId is null (Wallet) and from is OTE, it decreases OTE limit.
      }
    }

    return metrics;
  }
}
