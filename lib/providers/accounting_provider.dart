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

  AccountingProvider() {
    _initGlobal();
    _initCostCenters();
    loadTheme();
  }

  void _initGlobal() {
    _service.getFundTransfers().listen((data) {
      _transfers = data;
      notifyListeners();
    });
    _service.getPersonalAdjustments().listen((data) {
      _adjustments = data;
      notifyListeners();
    });
    _service.getExpenses().listen((data) {
      _allExpenses = data;
      notifyListeners();
    });
    _fixedSub = _service.getFixedAmounts().listen((data) {
      _fixedAmounts = data;
      notifyListeners();
    });
    _realSub = _service.getRealBalance().listen((data) {
      _realBalance = data;
      notifyListeners();
    });
  }

  void _initCostCenters() {
    _service.getCostCenters().listen((data) {
      _costCenters = data;
      if (_activeCostCenterId == null && _costCenters.isNotEmpty) {
        setActiveCostCenter(_costCenters.first.id);
      }
      notifyListeners();
    });
  }

  void setActiveCostCenter(String id) {
    _activeCostCenterId = id;
    _subscribeToCenterData(id);
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isSyncing = true;
    _lastSync = DateTime.now();
    notifyListeners();

    // Re-initialize everything
    _initGlobal();
    _initCostCenters();
    if (_activeCostCenterId != null) {
      _subscribeToCenterData(_activeCostCenterId!);
    }

    // Give it a moment to feel like a real refresh
    await Future.delayed(const Duration(seconds: 2));
    _isSyncing = false;
    notifyListeners();
  }

  void _subscribeToCenterData(String id) {
    _catSub?.cancel();
    _allocSub?.cancel();
    _donSub?.cancel();
    _expSub?.cancel();
    _adjSub?.cancel();
    _centerRealSub?.cancel();
    _budgetPeriodSub?.cancel();

    _catSub = _service.getCategories(id).listen((data) {
      _categories = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _allocSub = _service.getAllocations(id).listen((data) {
      _allocations = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _donSub = _service.getDonations(id).listen((data) {
      _donations = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _expSub = _service.getExpenses(costCenterId: id).listen((data) {
      _expenses = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _adjSub = _service.getCostCenterAdjustments(id).listen((data) {
      _centerAdjustments = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
    _centerRealSub = _service.getCostCenterRealBalance(id).listen((data) {
      _costCenterRealBalance = data;
      notifyListeners();
    });
    _budgetPeriodSub = _service.getBudgetPeriods(id).listen((data) {
      _budgetPeriods = data;
      _lastSync = DateTime.now();
      notifyListeners();
    });
  }

  // --- Balance Calculations ---

  // --- Balance Calculations ---

  double get personalBalance {
    // Total money received from generic ISKCON transfers
    double totalTransfers = _transfers
        .where((t) => t.type == TransferType.TO_PERSONAL)
        .fold(0, (sum, item) => sum + item.amount);
    
    // Expenses paid specifically from Personal Account
    double personalExpenses = _allExpenses
        .where((e) => e.moneySource == MoneySource.PERSONAL)
        .fold(0, (sum, item) => sum + item.amount);

    // Manual adjustments (Balance additions/removals)
    double debits = _adjustments
        .where((a) => a.type == AdjustmentType.DEBIT)
        .fold(0, (sum, item) => sum + item.amount);
    double credits = _adjustments
        .where((a) => a.type == AdjustmentType.CREDIT)
        .fold(0, (sum, item) => sum + item.amount);

    // Fixed Amounts (Stored Balances)
    double fixedTotal = _fixedAmounts.fold(0, (sum, item) => sum + item.amount);

    return totalTransfers - personalExpenses - debits + credits + fixedTotal;
  }

  // --- Cost Center Balance Calculations (OTE/PME) ---

  double _getAdjustmentTotal(BudgetType type) {
    double debits = _centerAdjustments
        .where((a) => a.budgetType == type && a.type == AdjustmentType.DEBIT)
        .fold(0, (sum, a) => sum + a.amount);
    double credits = _centerAdjustments
        .where((a) => a.budgetType == type && a.type == AdjustmentType.CREDIT)
        .fold(0, (sum, a) => sum + a.amount);
    return credits - debits;
  }

  // --- Budget Remaining Calculations (Limit - Spent) ---

  /// Get PME allocated for a specific month across all budget periods
  double getPmeForMonth(String month) {
    double total = 0;
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      if (period.includesMonth(month)) {
        total += period.getPmeForMonth(month);
      }
    }
    return total;
  }

  double get oteBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    // Use budget periods exclusively
    double oteAllocation = _getTotalOteFromPeriods();
    
    // Only count donations that are MERGED to a category of type OTE
    double oteDonations = 0;
    for (var donation in _donations) {
      if (donation.mode == DonationMode.MERGE_TO_BUDGET && donation.budgetCategoryId != null) {
        try {
          final cat = _categories.firstWhere((c) => c.id == donation.budgetCategoryId);
          if (cat.budgetType == BudgetType.OTE) {
            oteDonations += donation.amount;
          }
        } catch (_) {}
      }
    }

    // Include if NOT Personal OR (if Personal AND Settled)
    double oteSpent = _expenses
        .where((e) => e.budgetType == BudgetType.OTE && (e.moneySource != MoneySource.PERSONAL || e.isSettled))
        .fold(0, (sum, item) => sum + item.amount);

    double adjustments = _getAdjustmentTotal(BudgetType.OTE);

    // Internal Transfers: Subtract outgoing, Add incoming
    double outgoingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId != null)
        .where((t) => _categories.any((c) => c.id == t.fromCategoryId && c.budgetType == BudgetType.OTE))
        .fold(0.0, (sum, t) => sum + t.amount);
    
    double incomingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId != null)
        .where((t) => _categories.any((c) => c.id == t.toCategoryId && c.budgetType == BudgetType.OTE))
        .fold(0.0, (sum, t) => sum + t.amount);

    return oteAllocation + oteDonations - oteSpent + adjustments - outgoingTransfers + incomingTransfers;
  }

  double get pmeBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    // Use budget periods exclusively
    double pmeAllocationTotal = _getTotalPmeFromPeriods();

    // Only count donations that are MERGED to a category of type PME
    double pmeDonations = 0;
    for (var donation in _donations) {
      if (donation.mode == DonationMode.MERGE_TO_BUDGET && donation.budgetCategoryId != null) {
        try {
          final cat = _categories.firstWhere((c) => c.id == donation.budgetCategoryId);
          if (cat.budgetType == BudgetType.PME) {
            pmeDonations += donation.amount;
          }
        } catch (_) {}
      }
    }

    // Include if NOT Personal OR (if Personal AND Settled)
    double pmeSpent = _expenses
        .where((e) => e.budgetType == BudgetType.PME && (e.moneySource != MoneySource.PERSONAL || e.isSettled))
        .fold(0, (sum, item) => sum + item.amount);

    // Advances are subtracted in the "transit period" (unsettled) 
    // to ensure the Center Balance drops as soon as money is moved to Personal Pocket.
    // Once the Personal Expense is "Settled", the deduction shifts to 'pmeSpent'.

    double adjustments = _getAdjustmentTotal(BudgetType.PME);

    // Internal Transfers: Subtract outgoing, Add incoming
    double outgoingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId != null)
        .where((t) => _categories.any((c) => c.id == t.fromCategoryId && c.budgetType == BudgetType.PME))
        .fold(0.0, (sum, t) => sum + t.amount);
    
    double incomingTransfers = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId != null)
        .where((t) => _categories.any((c) => c.id == t.toCategoryId && c.budgetType == BudgetType.PME))
        .fold(0.0, (sum, t) => sum + t.amount);

    return pmeAllocationTotal + pmeDonations - pmeSpent + adjustments - advanceUnsettled - outgoingTransfers + incomingTransfers;
  }



  // --- Flow: Real Money at ISKCON ---
  
  /// "Advance Unsettled" -> Shows how much amount removed (Advanced) from THIS Cost Center but unsettled.
  /// Calculation: (Total Advances taken from this Center) - (Total Personal Expenses for this Center)
  double get advanceUnsettled {
    final center = activeCostCenter;
    if (center == null) return 0;

    // 1. Total Advances taken from THIS center (TO_PERSONAL type only)
    double totalAdvancesFromCenter = _transfers
        .where((t) => t.costCenterId == center.id && t.type == TransferType.TO_PERSONAL)
        .fold<double>(0.0, (sum, t) => sum + t.amount);

    // 2. Personal Expenses made for THIS center
    // 2. Personal Expenses made for THIS center AND Settled
    double settledAmount = _expenses
        .where((e) => e.moneySource == MoneySource.PERSONAL && e.isSettled)
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    return totalAdvancesFromCenter - settledAmount;
  }

  // REMOVED totalIskconBalance as requested

  int _getMonthsCount(CostCenter center) {
    try {
      DateTime startDate = DateFormat('yyyy-MM').parse(center.pmeStartMonth);
      DateTime now = DateTime.now();
      int count = (now.year - startDate.year) * 12 + (now.month - startDate.month) + 1;
      return count < 1 ? 1 : count;
    } catch (_) {
      return 1;
    }
  }

  /// Total Budget Remaining in the Cost Center (Temple Allocation + All Donations - Total Spent)
  double get costCenterBudgetBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    // 1. Total Baseline Allocation from Temple
    double totalPmeBaseline = 0;
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      for (var month in period.getAllMonths()) {
        if (isMonthInPastOrCurrent(month)) {
          totalPmeBaseline += period.defaultPmeAmount;
        }
      }
    }
    double totalOteBaseline = _getTotalOteFromPeriods(); // Assuming period OTE is the baseline

    // 2. Total Donations (Earmarked + Wallet)
    double totalDonations = _donations.fold(0.0, (sum, d) => sum + d.amount);

    // 3. Total Expenses (Non-personal)
    double totalExpenses = _expenses
        .where((e) => e.moneySource != MoneySource.PERSONAL)
        .fold(0.0, (sum, e) => sum + e.amount);

    // 4. Adjustments
    double adjustments = _getAdjustmentTotal(BudgetType.PME) + _getAdjustmentTotal(BudgetType.OTE);

    // 5. Advances (Money out but not spent yet)
    double advances = advanceUnsettled;

    return totalPmeBaseline + totalOteBaseline + totalDonations - totalExpenses + adjustments - advances;
  }

  /// Wallet / Unallocated Balance (The "Petty Cash" or "General Fund")
  /// formula: remaining non budgeted + donation (wallet) + expense through wallet
  double get walletBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    // 1. "remaining non budgeted" (Unallocated portion of the base budget)
    // For PME: (Total Baseline PME from Temple - Total Earmarked categories)
    double totalPmeBaseline = 0;
    int totalMonthsElapsedInPeriods = 0;
    final Set<String> elapsedMonths = {};

    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      for (var month in period.getAllMonths()) {
        if (isMonthInPastOrCurrent(month)) {
          elapsedMonths.add(month);
          totalPmeBaseline += period.defaultPmeAmount; // Use baseline default
        }
      }
    }
    totalMonthsElapsedInPeriods = elapsedMonths.length;

    double earmarkedPmeMonthly = _categories
        .where((c) => c.budgetType == BudgetType.PME)
        .fold(0, (sum, c) => sum + c.targetAmount);
    
    double unallocatedPme = 0;
    // For PME: (Total Baseline PME from Temple - Total Budgeted PME)
    // This represents the "Savings" diverted to the wallet by reducing the monthly budget.
    final Set<String> months = {};
    for (var p in _budgetPeriods.where((p) => p.isActive)) {
      months.addAll(p.getAllMonths().where((m) => isMonthInPastOrCurrent(m)));
    }

    for (var m in months) {
      double monthlyBaseline = 0;
      double monthlyBudgeted = 0;
      for (var p in _budgetPeriods.where((p) => p.isActive)) {
        if (p.includesMonth(m)) {
          monthlyBaseline += p.defaultPmeAmount;
          monthlyBudgeted += p.getPmeForMonth(m);
        }
      }
      if (monthlyBaseline > monthlyBudgeted) {
        unallocatedPme += (monthlyBaseline - monthlyBudgeted);
      }
    }

    // For OTE: (Total Budgeted OTE) - (Total Earmarked OTE Categories)
    double totalOteAllocated = _getTotalOteFromPeriods();
    double earmarkedOte = _categories
        .where((c) => c.budgetType == BudgetType.OTE)
        .fold(0, (sum, c) => sum + c.targetAmount);
    double unallocatedOte = totalOteAllocated - earmarkedOte;

    // 2. "donation" (Donations specifically marked for Wallet)
    double walletDonations = _donations
        .where((d) => d.mode == DonationMode.WALLET)
        .fold(0, (sum, item) => sum + item.amount);

    // 3. "expense through wallet" (Expenses specifically paid from Wallet)
    double walletExpenses = _expenses
        .where((e) => e.moneySource == MoneySource.WALLET)
        .fold(0, (sum, item) => sum + item.amount);

    // 4. Center-level adjustments (not tied to any category) are also unallocated funds
    double centerAdjustments = _centerAdjustments
        .where((a) => a.categoryId == null)
        .fold(0, (sum, a) => sum + (a.type == AdjustmentType.CREDIT ? a.amount : -a.amount));

    // 5. Internal Transfers to/from Wallet
    // Transfers FROM category TO Wallet (toCategoryId is null)
    double transfersIntoWallet = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.toCategoryId == null && t.fromCategoryId != null)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    // Transfers FROM Wallet (not supported yet in UI, but for logic completeness) TO category
    double transfersOutOfWallet = _transfers
        .where((t) => t.type == TransferType.CATEGORY_TO_CATEGORY && t.fromCategoryId == null && t.toCategoryId != null)
        .fold(0.0, (sum, t) => sum + t.amount);

    return unallocatedPme + unallocatedOte + walletDonations - walletExpenses + centerAdjustments + transfersIntoWallet - transfersOutOfWallet;
  }

  Map<String, double> getCategoryStatus(BudgetCategory cat) {
    final center = activeCostCenter;
    double budget = cat.targetAmount;
    
    if (cat.budgetType == BudgetType.PME) {
      // Calculate budget for this category based on how many months have elapsed in active periods
      int monthsCount = 0;
      final Set<String> elapsedMonths = {};
      for (var period in _budgetPeriods.where((p) => p.isActive)) {
        for (var month in period.getAllMonths()) {
          if (isMonthInPastOrCurrent(month)) {
            elapsedMonths.add(month);
          }
        }
      }
      monthsCount = elapsedMonths.length;
      budget = budget * monthsCount;
    }

    final donations = _donations
        .where((d) => d.mode == DonationMode.MERGE_TO_BUDGET && d.budgetCategoryId == cat.id)
        .fold(0.0, (sum, d) => sum + d.amount);
    final spent = _expenses
        .where((e) => e.categoryId == cat.id)
        .fold(0.0, (sum, e) => sum + e.amount);

    double adjustments = _centerAdjustments
        .where((a) => a.categoryId == cat.id)
        .fold(0, (sum, a) => sum + (a.type == AdjustmentType.CREDIT ? a.amount : -a.amount));

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

  BudgetType getBudgetTypeForCategory(String categoryId) {
    return _categories.firstWhere((c) => c.id == categoryId).budgetType;
  }

  double _getTotalPmeFromPeriods() {
    double total = 0;
    for (var period in _budgetPeriods) {
      if (period.isActive) {
        for (var month in period.getAllMonths()) {
          if (isMonthInPastOrCurrent(month)) {
            total += period.getPmeForMonth(month);
          }
        }
      }
    }
    return total;
  }

  double _getTotalOteFromPeriods() {
    return _budgetPeriods
        .where((p) => p.isActive)
        .fold(0.0, (sum, p) => sum + p.oteAmount);
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

  @override
  void dispose() {
    _catSub?.cancel();
    _allocSub?.cancel();
    _donSub?.cancel();
    _expSub?.cancel();
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
  // --- Category <-> Wallet Transfers ---
  Future<void> transferBetweenCategoryAndWallet({
    required String categoryId,
    required double amount,
    required bool isToWallet, // true = Category to Wallet, false = Wallet to Category
    required String remarks,
  }) async {
    if (_activeCostCenterId == null) return;

    // We represent these transfers using the existing FundTransfer model.
    // However, the model needs to distinguish between "Category -> Unallocated (Wallet)" and "Unallocated (Wallet) -> Category".
    // Convention:
    // - From Category To Wallet: fromCategoryId = ID, toCategoryId = NULL
    // - From Wallet To Category: fromCategoryId = NULL, toCategoryId = ID
    
    final transfer = FundTransfer(
      id: '', // Service generates ID
      costCenterId: _activeCostCenterId!,
      amount: amount,
      date: DateTime.now(),
      remarks: remarks,
      type: TransferType.CATEGORY_TO_CATEGORY,
      fromCategoryId: isToWallet ? categoryId : null, // If to wallet, FROM is cat
      toCategoryId: isToWallet ? null : categoryId,    // If from wallet, TO is cat
    );

    await _service.addFundTransfer(transfer);
  }

  Map<String, Map<String, double>> getMonthlyPerformanceMetrics() {
    // Map<YYYY-MM, {pme_budget, ote_budget, pme_actual, ote_actual}>
    final Map<String, Map<String, double>> metrics = {};

    // 1. Populate Budget Data from Active Periods
    for (var period in _budgetPeriods.where((p) => p.isActive)) {
      for (var month in period.getAllMonths()) {
        metrics.putIfAbsent(month, () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});
        
        // PME is monthly
        metrics[month]!['pme_budget'] = (metrics[month]!['pme_budget'] ?? 0) + period.getPmeForMonth(month);
        
        // OTE is total per period, so we don't necessarily split it by month for "Budget".
        // However, user might want to see it distributed? 
        // For now, let's just track Actual OTE usage per month.
        // OTE Budget is a pool, not monthly. We can show Period total separately or divided?
        // Let's leave OTE Budget as 0 per month for now, as it's a "Project" budget.
      }
    }

    // 2. Populate Expense Data
    // We rely on expense.budgetMonth which we just added. 
    // If null, we fall back to expense.date
    for (var expense in _expenses) {
      if (expense.moneySource == MoneySource.PERSONAL && !expense.isSettled) continue;

      String month = expense.budgetMonth ?? DateFormat('yyyy-MM').format(expense.date);
      metrics.putIfAbsent(month, () => {'pme_budget': 0.0, 'ote_budget': 0.0, 'pme_actual': 0.0, 'ote_actual': 0.0});

      if (expense.budgetType == BudgetType.PME) {
        metrics[month]!['pme_actual'] = (metrics[month]!['pme_actual'] ?? 0) + expense.amount;
      } else {
        metrics[month]!['ote_actual'] = (metrics[month]!['ote_actual'] ?? 0) + expense.amount;
      }
    }

    return metrics;
  }
}
