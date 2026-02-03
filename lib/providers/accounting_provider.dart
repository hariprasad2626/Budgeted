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
import '../services/firestore_service.dart';

class AccountingProvider with ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  List<CostCenter> _costCenters = [];
  String? _activeCostCenterId;

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
  double _realBalance = 0;
  double _costCenterRealBalance = 0;
  DateTime _lastSync = DateTime.now();
  bool _isSyncing = false;

  List<CostCenter> get costCenters => _costCenters;
  String? get activeCostCenterId => _activeCostCenterId;
  DateTime get lastSync => _lastSync;
  bool get isSyncing => _isSyncing;
  
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

  AccountingProvider() {
    _initGlobal();
    _initCostCenters();
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

  double get oteBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    double oteAllocation = center.defaultOteAmount;
    
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

    DateTime startDate;
    try {
      startDate = DateFormat('yyyy-MM').parse(center.pmeStartMonth);
    } catch (_) {
      startDate = DateTime(2026, 1);
    }
    
    DateTime now = DateTime.now();
    int monthsCount = (now.year - startDate.year) * 12 + (now.month - startDate.month) + 1;
    if (monthsCount < 1) monthsCount = 1;

    double pmeAllocationTotal = center.defaultPmeAmount * monthsCount;

    // Only count donations that are MERGED to a category of type PME
    double pmeDonations = 0;
    for (var donation in _donations) {
      if (donation.mode == DonationMode.MERGE_TO_BUDGET && donation.budgetCategoryId != null) {
        try {
          final cat = _categories.firstWhere((c) => c.id == donation.budgetCategoryId);
          if (cat.budgetType == BudgetType.PME) {
            if (donation.date.isAfter(startDate) || DateFormat('yyyy-MM').format(donation.date) == center.pmeStartMonth) {
              pmeDonations += donation.amount;
            }
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

  /// Total Budget Remaining in the Cost Center (PME + OTE + General Wallet Funds)
  double get costCenterBudgetBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    // pmeBalance includes: (PME Allocation + PME Category Donations - PME Spending + PME Adjustments - Advances)
    // oteBalance includes: (OTE Allocation + OTE Category Donations - OTE Spending + OTE Adjustments)
    
    // We only need to add donations that were NOT tied to a category (mode: WALLET)
    double unallocatedDonations = _donations
        .where((d) => d.mode == DonationMode.WALLET)
        .fold(0, (sum, item) => sum + item.amount);
        
    // Note: wallet-source expenses are already subtracted within pmeBalance / oteBalance 
    // because they are registered with a budgetType (PME/OTE).

    return pmeBalance + oteBalance + unallocatedDonations;
  }

  /// Wallet / Unallocated Balance (The "Petty Cash" or "General Fund")
  /// formula: remaining non budgeted + donation (wallet) + expense through wallet
  double get walletBalance {
    final center = activeCostCenter;
    if (center == null) return 0;

    double monthsCount = _getMonthsCount(center).toDouble();

    // 1. "remaining non budgeted" (Unallocated portion of the base budget)
    double earmarkedPme = _categories
        .where((c) => c.budgetType == BudgetType.PME)
        .fold(0, (sum, c) => sum + c.targetAmount);
    double unallocatedPme = (center.defaultPmeAmount - earmarkedPme) * monthsCount;

    double earmarkedOte = _categories
        .where((c) => c.budgetType == BudgetType.OTE)
        .fold(0, (sum, c) => sum + c.targetAmount);
    double unallocatedOte = center.defaultOteAmount - earmarkedOte;

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
    
    if (cat.budgetType == BudgetType.PME && center != null) {
      budget = budget * _getMonthsCount(center);
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

  @override
  void dispose() {
    _catSub?.cancel();
    _allocSub?.cancel();
    _donSub?.cancel();
    _expSub?.cancel();
    _fixedSub?.cancel();
    _realSub?.cancel();
    _centerRealSub?.cancel();
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
}
