import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/budget_category.dart';
import '../services/firestore_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expenseToEdit;
  final MoneySource? defaultSource;
  const AddExpenseScreen({super.key, this.expenseToEdit, this.defaultSource});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String? _selectedCategoryName; 
  String? _selectedCategoryId;   
  MoneySource _moneySource = MoneySource.WALLET;
  DateTime _selectedDate = DateTime.now();
  BudgetType? _derivedBudgetType;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _amountController.text = e.amount.toString();
      _remarksController.text = e.remarks;
      _selectedCategoryId = e.categoryId;
      _moneySource = e.moneySource;
      _selectedDate = e.date;
      _derivedBudgetType = e.budgetType;
    } else if (widget.defaultSource != null) {
      _moneySource = widget.defaultSource!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final allCats = provider.categories;
    
    if (widget.expenseToEdit != null && _selectedCategoryName == null && _selectedCategoryId != null) {
      try {
        final cat = allCats.firstWhere((c) => c.id == _selectedCategoryId);
        _selectedCategoryName = cat.category;
      } catch (_) {}
    }

    final parentCategories = allCats.map((c) => c.category).toSet().toList()..sort();
    final filteredSubCats = allCats.where((c) => 
      c.category == _selectedCategoryName && 
      (c.isActive || c.id == _selectedCategoryId)
    ).toList();

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.defaultSource != null)
                      InputDecorator(
                        decoration: _inputDecoration('Money Source'),
                        child: Text(
                          _getMoneySourceLabel(widget.defaultSource!),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      )
                    else
                      DropdownButtonFormField<MoneySource>(
                        isExpanded: true,
                        decoration: _inputDecoration('Money Source'),
                        value: _moneySource,
                        items: MoneySource.values.where((s) => s != MoneySource.PERSONAL).map((s) => DropdownMenuItem(
                          value: s, 
                          child: Text(_getMoneySourceLabel(s)),
                        )).toList(),
                        onChanged: (val) => setState(() => _moneySource = val!),
                      ),
                    if (_moneySource == MoneySource.ISKCON) ...[
                      const SizedBox(height: 24),
                      Text('CATEGORY', style: _labelStyle),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: _inputDecoration('Main Category'),
                        value: parentCategories.contains(_selectedCategoryName) ? _selectedCategoryName : null,
                        items: parentCategories.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryName = val;
                            _selectedCategoryId = null;
                            _derivedBudgetType = null;
                          });
                        },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: _inputDecoration('Sub Category'),
                        value: filteredSubCats.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                        items: filteredSubCats.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.subCategory} (${c.budgetType.name})'),
                        )).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                            if (val != null) _derivedBudgetType = provider.getBudgetTypeForCategory(val);
                          });
                        },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('DETAILS', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: _inputDecoration('Amount').copyWith(prefixText: '₹ '),
                      keyboardType: TextInputType.number,
                      validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _inputDecoration('Date'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MMMM dd, yyyy').format(_selectedDate)),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      decoration: _inputDecoration('Remarks / Description'),
                      maxLines: 2,
                      validator: (val) => (val == null || val.isEmpty) ? 'Remarks are mandatory' : null,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.expenseToEdit == null ? 'SAVE EXPENSE' : 'UPDATE EXPENSE',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.expenseToEdit == null ? 'New Expense' : 'Edit Expense',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => TextStyle(
    fontSize: 12, 
    fontWeight: FontWeight.bold, 
    color: Colors.tealAccent.shade700,
    letterSpacing: 1.1,
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    filled: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _getMoneySourceLabel(MoneySource source) {
    switch (source) {
      case MoneySource.ISKCON: return 'Cost Center Budget';
      case MoneySource.WALLET: return 'Cash Wallet';
      case MoneySource.PERSONAL: return 'Personal Account';
    }
  }

  void _submit() async {
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    
    // Custom validation logic
    if (_amountController.text.isEmpty) {
      if (!_formKey.currentState!.validate()) return; // Trigger visible validators
      return;
    }
    // Check Category only if source is ISKCON
    if (_moneySource == MoneySource.ISKCON && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    
    if (provider.activeCostCenterId == null) return;

    // Determine payload
    String finalCatId = '';
    BudgetType finalBudgetType = BudgetType.OTE;

    if (_moneySource == MoneySource.ISKCON) {
       finalCatId = _selectedCategoryId!;
       finalBudgetType = _derivedBudgetType!;
    } else {
       // For Wallet/Personal, try to find a 'General' category or just pick the first one as placeholder
       // This ensures the data model constraint is met.
       final generalCat = provider.categories.firstWhere(
          (c) => c.category.toLowerCase().contains('general') || c.subCategory.toLowerCase().contains('general'),
          orElse: () => provider.categories.isNotEmpty ? provider.categories.first : 
                        BudgetCategory(
                          id: 'UNKNOWN', 
                          costCenterId: '', 
                          category: 'General', 
                          subCategory: 'General', 
                          budgetType: BudgetType.OTE, 
                          targetAmount: 0,
                          isActive: true,
                          remarks: 'Auto Generic',
                          createdAt: DateTime.now()
                        )
       );
       finalCatId = generalCat.id;
       finalBudgetType = generalCat.budgetType;
    }

    final expense = Expense(
      id: widget.expenseToEdit?.id ?? const Uuid().v4(),
      costCenterId: provider.activeCostCenterId!,
      categoryId: finalCatId,
      amount: double.parse(_amountController.text).abs(),
      budgetType: finalBudgetType,
      moneySource: _moneySource,
      date: _selectedDate,
      remarks: _remarksController.text,
    );

    if (widget.expenseToEdit == null) {
      await FirestoreService().addExpense(expense);
    } else {
      await FirestoreService().updateExpense(expense);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
