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
import '../models/activity_log.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _logActivity({
    required ActivityType activityType,
    required EntityType entityType,
    required String entityId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    required String remarks,
  }) async {
    final log = ActivityLog(
      id: '',
      activityType: activityType,
      entityType: entityType,
      entityId: entityId,
      oldData: oldData,
      newData: newData,
      timestamp: DateTime.now(),
      remarks: remarks,
    );
    await _db.collection('activity_logs').add(log.toMap());
  }

  Stream<List<ActivityLog>> getActivityLogs() {
    return _db.collection('activity_logs')
      .orderBy('timestamp', descending: true)
      .limit(200) // Keep it manageable
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ActivityLog.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> deleteActivityLog(String id) {
    return _db.collection('activity_logs').doc(id).delete();
  }

  // Generic methods for Rollback/Undo
  Future<void> setDocument(String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).set(data);
  }

  Future<void> deleteDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }

  // --- Cost Centers ---
  Stream<List<CostCenter>> getCostCenters() {
    return _db.collection('cost_centers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CostCenter.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addCostCenter(CostCenter center) async {
    final docRef = await _db.collection('cost_centers').add(center.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.COST_CENTER,
      entityId: docRef.id,
      newData: center.toMap(),
      remarks: 'Added Cost Center: ${center.name}',
    );
  }

  Future<void> updateCostCenter(CostCenter center, {CostCenter? previousData}) async {
    await _db.collection('cost_centers').doc(center.id).update(center.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.COST_CENTER,
      entityId: center.id,
      oldData: previousData?.toMap(),
      newData: center.toMap(),
      remarks: 'Updated Cost Center: ${center.name}',
    );
  }

  Future<void> deleteCostCenter(CostCenter center) async {
    await _db.collection('cost_centers').doc(center.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.COST_CENTER,
      entityId: center.id,
      oldData: center.toMap(),
      remarks: 'Deleted Cost Center: ${center.name}',
    );
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

  Future<List<BudgetCategory>> getAllCategories() async {
    final snapshot = await _db.collection('budget_categories').get();
    return snapshot.docs
        .map((doc) => BudgetCategory.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> addCategory(BudgetCategory category) async {
    final docRef = await _db.collection('budget_categories').add(category.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.CATEGORY,
      entityId: docRef.id,
      newData: category.toMap(),
      remarks: 'Added Category: ${category.category} > ${category.subCategory}',
    );
  }

  Future<void> updateCategory(BudgetCategory category, {BudgetCategory? previousData}) async {
    await _db
        .collection('budget_categories')
        .doc(category.id)
        .set(category.toMap(), SetOptions(merge: true));
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.CATEGORY,
      entityId: category.id,
      oldData: previousData?.toMap(),
      newData: category.toMap(),
      remarks: 'Updated Category: ${category.category}',
    );
  }

  Future<void> deleteCategory(BudgetCategory category) async {
    await _db.collection('budget_categories').doc(category.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.CATEGORY,
      entityId: category.id,
      oldData: category.toMap(),
      remarks: 'Deleted Category: ${category.category} > ${category.subCategory}',
    );
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

  Future<void> addAllocation(BudgetAllocation allocation) async {
    final docRef = await _db.collection('budget_allocations').add(allocation.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.ALLOCATION,
      entityId: docRef.id,
      newData: allocation.toMap(),
      remarks: 'Added Allocation: ${allocation.remarks} (₹${allocation.amount})',
    );
  }

  Future<void> deleteAllocation(BudgetAllocation allocation) async {
    await _db.collection('budget_allocations').doc(allocation.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.ALLOCATION,
      entityId: allocation.id,
      oldData: allocation.toMap(),
      remarks: 'Deleted Allocation: ${allocation.remarks} (₹${allocation.amount})',
    );
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

  Future<void> addDonation(Donation donation) async {
    final docRef = await _db.collection('donations').add(donation.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.DONATION,
      entityId: docRef.id,
      newData: donation.toMap(),
      remarks: 'Added Donation: ${donation.remarks} (₹${donation.amount})',
    );
  }

  Future<void> updateDonation(Donation donation, {Donation? previousData}) async {
    await _db.collection('donations').doc(donation.id).update(donation.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.DONATION,
      entityId: donation.id,
      oldData: previousData?.toMap(),
      newData: donation.toMap(),
      remarks: 'Updated Donation: ${donation.remarks}',
    );
  }

  Future<void> deleteDonation(Donation donation) async {
    await _db.collection('donations').doc(donation.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.DONATION,
      entityId: donation.id,
      oldData: donation.toMap(),
      remarks: 'Deleted Donation: ${donation.remarks} (₹${donation.amount})',
    );
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

  Future<void> addExpense(Expense expense) async {
    final docRef = await _db.collection('expenses').add(expense.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.EXPENSE,
      entityId: docRef.id,
      newData: expense.toMap(),
      remarks: 'Added Expense: ${expense.remarks} (₹${expense.amount})',
    );
  }

  Future<void> updateExpense(Expense expense, {Expense? previousData}) async {
    await _db.collection('expenses').doc(expense.id).update(expense.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.EXPENSE,
      entityId: expense.id,
      oldData: previousData?.toMap(),
      newData: expense.toMap(),
      remarks: 'Updated Expense: ${expense.remarks}',
    );
  }

  Future<void> deleteExpense(Expense expense) async {
    await _db.collection('expenses').doc(expense.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.EXPENSE,
      entityId: expense.id,
      oldData: expense.toMap(),
      remarks: 'Deleted Expense: ${expense.remarks} (₹${expense.amount})',
    );
  }

  // --- Fund Transfers (Global) ---
  Stream<List<FundTransfer>> getFundTransfers() {
    return _db.collection('fund_transfers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => FundTransfer.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList());
  }

  Future<void> addFundTransfer(FundTransfer transfer) async {
    final docRef = await _db.collection('fund_transfers').add(transfer.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.TRANSFER,
      entityId: docRef.id,
      newData: transfer.toMap(),
      remarks: 'Added Transfer: ${transfer.remarks} (₹${transfer.amount})',
    );
  }

  Future<void> updateFundTransfer(FundTransfer transfer, {FundTransfer? previousData}) async {
    await _db.collection('fund_transfers').doc(transfer.id).update(transfer.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.TRANSFER,
      entityId: transfer.id,
      oldData: previousData?.toMap(),
      newData: transfer.toMap(),
      remarks: 'Updated Transfer: ${transfer.remarks}',
    );
  }

  Future<void> deleteFundTransfer(FundTransfer transfer) async {
    await _db.collection('fund_transfers').doc(transfer.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.TRANSFER,
      entityId: transfer.id,
      oldData: transfer.toMap(),
      remarks: 'Deleted Transfer: ${transfer.remarks} (₹${transfer.amount})',
    );
  }

  // --- Personal Adjustments (Global) ---
  Stream<List<PersonalAdjustment>> getPersonalAdjustments() {
    return _db.collection('personal_adjustments').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => PersonalAdjustment.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addPersonalAdjustment(PersonalAdjustment adjustment) async {
    final docRef = await _db.collection('personal_adjustments').add(adjustment.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.ADJUSTMENT,
      entityId: docRef.id,
      newData: adjustment.toMap(),
      remarks: 'Added Adjustment: ${adjustment.remarks} (₹${adjustment.amount})',
    );
  }

  Future<void> updatePersonalAdjustment(PersonalAdjustment adjustment, {PersonalAdjustment? previousData}) async {
    await _db.collection('personal_adjustments').doc(adjustment.id).update(adjustment.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.ADJUSTMENT,
      entityId: adjustment.id,
      oldData: previousData?.toMap(),
      newData: adjustment.toMap(),
      remarks: 'Updated Adjustment: ${adjustment.remarks}',
    );
  }

  Future<void> deletePersonalAdjustment(PersonalAdjustment adjustment) async {
    await _db.collection('personal_adjustments').doc(adjustment.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.ADJUSTMENT,
      entityId: adjustment.id,
      oldData: adjustment.toMap(),
      remarks: 'Deleted Adjustment: ${adjustment.remarks} (₹${adjustment.amount})',
    );
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

  Future<void> addCostCenterAdjustment(CostCenterAdjustment adjustment) async {
    final docRef = await _db.collection('cost_center_adjustments').add(adjustment.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.ADJUSTMENT,
      entityId: docRef.id,
      newData: adjustment.toMap(),
      remarks: 'Added Center Adjustment: ${adjustment.remarks} (₹${adjustment.amount})',
    );
  }

  Future<void> updateCostCenterAdjustment(CostCenterAdjustment adjustment, {CostCenterAdjustment? previousData}) async {
    await _db.collection('cost_center_adjustments').doc(adjustment.id).update(adjustment.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.ADJUSTMENT,
      entityId: adjustment.id,
      oldData: previousData?.toMap(),
      newData: adjustment.toMap(),
      remarks: 'Updated Center Adjustment: ${adjustment.remarks}',
    );
  }

  Future<void> deleteCostCenterAdjustment(CostCenterAdjustment adjustment) async {
    await _db.collection('cost_center_adjustments').doc(adjustment.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.ADJUSTMENT,
      entityId: adjustment.id,
      oldData: adjustment.toMap(),
      remarks: 'Deleted Center Adjustment: ${adjustment.remarks} (₹${adjustment.amount})',
    );
  }

  // --- Fixed Amounts (Personal) ---
  Stream<List<FixedAmount>> getFixedAmounts() {
    return _db.collection('fixed_amounts').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => FixedAmount.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addFixedAmount(FixedAmount item) async {
    final docRef = await _db.collection('fixed_amounts').add(item.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.FIXED_AMOUNT,
      entityId: docRef.id,
      newData: item.toMap(),
      remarks: 'Added Fixed Balance: ${item.remarks} (₹${item.amount})',
    );
  }

  Future<void> updateFixedAmount(FixedAmount item, {FixedAmount? previousData}) async {
    await _db.collection('fixed_amounts').doc(item.id).update(item.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.FIXED_AMOUNT,
      entityId: item.id,
      oldData: previousData?.toMap(),
      newData: item.toMap(),
      remarks: 'Updated Fixed Balance: ${item.remarks}',
    );
  }

  Future<void> deleteFixedAmount(FixedAmount item) async {
    await _db.collection('fixed_amounts').doc(item.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.FIXED_AMOUNT,
      entityId: item.id,
      oldData: item.toMap(),
      remarks: 'Deleted Fixed Balance: ${item.remarks} (₹${item.amount})',
    );
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

  Future<void> addBudgetPeriod(BudgetPeriod period) async {
    final docRef = await _db.collection('budget_periods').add(period.toMap());
    await _logActivity(
      activityType: ActivityType.CREATE,
      entityType: EntityType.BUDGET_PERIOD,
      entityId: docRef.id,
      newData: period.toMap(),
      remarks: 'Added Budget Period: ${period.remarks}',
    );
  }

  Future<void> updateBudgetPeriod(BudgetPeriod period, {BudgetPeriod? previousData}) async {
    await _db.collection('budget_periods').doc(period.id).update(period.toMap());
    await _logActivity(
      activityType: ActivityType.UPDATE,
      entityType: EntityType.BUDGET_PERIOD,
      entityId: period.id,
      oldData: previousData?.toMap(),
      newData: period.toMap(),
      remarks: 'Updated Budget Period: ${period.remarks}',
    );
  }

  Future<void> deleteBudgetPeriod(BudgetPeriod period) async {
    await _db.collection('budget_periods').doc(period.id).delete();
    await _logActivity(
      activityType: ActivityType.DELETE,
      entityType: EntityType.BUDGET_PERIOD,
      entityId: period.id,
      oldData: period.toMap(),
      remarks: 'Deleted Budget Period: ${period.remarks}',
    );
  }
}
