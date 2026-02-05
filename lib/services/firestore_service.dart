import 'package:cloud_firestore/cloud_firestore.dart';
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

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Cost Centers ---
  Stream<List<CostCenter>> getCostCenters() {
    return _db.collection('cost_centers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CostCenter.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addCostCenter(CostCenter center) {
    return _db.collection('cost_centers').add(center.toMap());
  }

  Future<void> updateCostCenter(CostCenter center) {
    return _db.collection('cost_centers').doc(center.id).update(center.toMap());
  }

  // --- Categories (Filtered by Cost Center) ---
  Stream<List<BudgetCategory>> getCategories(String costCenterId) {
    return _db
        .collection('budget_categories')
        .where('costCenterId', isEqualTo: costCenterId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetCategory.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addCategory(BudgetCategory category) {
    return _db.collection('budget_categories').add(category.toMap());
  }

  Future<void> updateCategory(BudgetCategory category) {
    return _db
        .collection('budget_categories')
        .doc(category.id)
        .set(category.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCategory(String id) {
    return _db.collection('budget_categories').doc(id).delete();
  }

  // --- Allocations (Filtered by Cost Center) ---
  Stream<List<BudgetAllocation>> getAllocations(String costCenterId) {
    return _db
        .collection('budget_allocations')
        .where('costCenterId', isEqualTo: costCenterId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetAllocation.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addAllocation(BudgetAllocation allocation) {
    return _db.collection('budget_allocations').add(allocation.toMap());
  }

  // --- Donations (Filtered by Cost Center) ---
  Stream<List<Donation>> getDonations(String costCenterId) {
    return _db
        .collection('donations')
        .where('costCenterId', isEqualTo: costCenterId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Donation.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addDonation(Donation donation) {
    return _db.collection('donations').add(donation.toMap());
  }

  Future<void> updateDonation(Donation donation) {
    return _db.collection('donations').doc(donation.id).update(donation.toMap());
  }

  Future<void> deleteDonation(String id) {
    return _db.collection('donations').doc(id).delete();
  }

  // --- Expenses (Filtered by Cost Center for Ledger, but all for Personal Account) ---
  Stream<List<Expense>> getExpenses({String? costCenterId}) {
    Query query = _db.collection('expenses');
    if (costCenterId != null) {
      query = query.where('costCenterId', isEqualTo: costCenterId);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addExpense(Expense expense) {
    return _db.collection('expenses').add(expense.toMap());
  }

  Future<void> updateExpense(Expense expense) {
    return _db.collection('expenses').doc(expense.id).update(expense.toMap());
  }

  Future<void> deleteExpense(String id) {
    return _db.collection('expenses').doc(id).delete();
  }

  // --- Fund Transfers (Global) ---
  Stream<List<FundTransfer>> getFundTransfers() {
    return _db.collection('fund_transfers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => FundTransfer.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addFundTransfer(FundTransfer transfer) {
    return _db.collection('fund_transfers').add(transfer.toMap());
  }

  Future<void> updateFundTransfer(FundTransfer transfer) {
    return _db.collection('fund_transfers').doc(transfer.id).update(transfer.toMap());
  }

  Future<void> deleteFundTransfer(String id) {
    return _db.collection('fund_transfers').doc(id).delete();
  }

  // --- Personal Adjustments (Global) ---
  Stream<List<PersonalAdjustment>> getPersonalAdjustments() {
    return _db.collection('personal_adjustments').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => PersonalAdjustment.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addPersonalAdjustment(PersonalAdjustment adjustment) {
    return _db.collection('personal_adjustments').add(adjustment.toMap());
  }

  Future<void> updatePersonalAdjustment(PersonalAdjustment adjustment) {
    return _db.collection('personal_adjustments').doc(adjustment.id).update(adjustment.toMap());
  }

  Future<void> deletePersonalAdjustment(String id) {
    return _db.collection('personal_adjustments').doc(id).delete();
  }

  // --- Cost Center Adjustments ---
  Stream<List<CostCenterAdjustment>> getCostCenterAdjustments(String costCenterId) {
    return _db
        .collection('cost_center_adjustments')
        .where('costCenterId', isEqualTo: costCenterId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CostCenterAdjustment.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addCostCenterAdjustment(CostCenterAdjustment adjustment) {
    return _db.collection('cost_center_adjustments').add(adjustment.toMap());
  }

  Future<void> updateCostCenterAdjustment(CostCenterAdjustment adjustment) {
    return _db.collection('cost_center_adjustments').doc(adjustment.id).update(adjustment.toMap());
  }

  Future<void> deleteCostCenterAdjustment(String id) {
    return _db.collection('cost_center_adjustments').doc(id).delete();
  }

  // --- Fixed Amounts (Personal) ---
  Stream<List<FixedAmount>> getFixedAmounts() {
    return _db.collection('fixed_amounts').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => FixedAmount.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addFixedAmount(FixedAmount item) {
    return _db.collection('fixed_amounts').add(item.toMap());
  }

  Future<void> updateFixedAmount(FixedAmount item) {
    return _db.collection('fixed_amounts').doc(item.id).update(item.toMap());
  }

  Future<void> deleteFixedAmount(String id) {
    return _db.collection('fixed_amounts').doc(id).delete();
  }

  // --- Real Balance (Personal Reconciliation) ---
  Stream<double> getRealBalance() {
    return _db
        .collection('personal_meta')
        .doc('real_balance')
        .snapshots()
        .map((doc) => (doc.data()?['amount'] as num?)?.toDouble() ?? 0.0);
  }

  Future<void> updateRealBalance(double amount) {
    return _db
        .collection('personal_meta')
        .doc('real_balance')
        .set({'amount': amount, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
  // --- Cost Center Reconciliation ---
  Stream<double> getCostCenterRealBalance(String costCenterId) {
    return _db
        .collection('cost_center_meta')
        .doc(costCenterId)
        .snapshots()
        .map((doc) => (doc.data()?['real_balance'] as num?)?.toDouble() ?? 0.0);
  }

  Future<void> updateCostCenterRealBalance(String costCenterId, double amount) {
    return _db
        .collection('cost_center_meta')
        .doc(costCenterId)
        .set({
          'real_balance': amount, 
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
  }

  // --- Budget Periods (Filtered by Cost Center) ---
  Stream<List<BudgetPeriod>> getBudgetPeriods(String costCenterId) {
    return _db
        .collection('budget_periods')
        .where('costCenterId', isEqualTo: costCenterId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BudgetPeriod.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  Future<void> addBudgetPeriod(BudgetPeriod period) {
    return _db.collection('budget_periods').add(period.toMap());
  }

  Future<void> updateBudgetPeriod(BudgetPeriod period) {
    return _db.collection('budget_periods').doc(period.id).update(period.toMap());
  }

  Future<void> deleteBudgetPeriod(String id) {
    return _db.collection('budget_periods').doc(id).delete();
  }
}
