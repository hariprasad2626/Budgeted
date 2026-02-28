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
  MoneySource _moneySource = MoneySource.ISKCON;
  DateTime _selectedDate = DateTime.now();
  BudgetType? _derivedBudgetType = BudgetType.PME;
  double _runningTotal = 0;

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
      _runningTotal = e.amount;
    } else if (widget.defaultSource != null) {
      _moneySource = widget.defaultSource!;
    }
  }

  void _updateRunningTotal(String val) {
    try {
       // Simple parser for 10+20 or 10 20
       final parts = val.replaceAll(',', '').split(RegExp(r'[+\s]'));
       double sum = 0;
       for (var p in parts) {
         if (p.trim().isNotEmpty) {
           sum += double.tryParse(p.trim()) ?? 0;
         }
       }
       setState(() {
         _runningTotal = sum;
       });
    } catch (_) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expenseToEdit == null ? 'New Expense' : 'Edit Expense'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.defaultSource == MoneySource.PERSONAL)
                InputDecorator(
                  decoration: _inputDecoration('Money Source'),
                  child: Text(
                    _getMoneySourceLabel(widget.defaultSource!),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                )
              else ...[
                Text('BUDGET POOL / SOURCE', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('Select Target Pool'),
                  value: _derivedBudgetType?.toString().split('.').last ?? 'PME',
                  items: [
                    DropdownMenuItem(value: 'PME', child: Text('PME (Monthly Budget) - ₹${provider.pmeBalance.toStringAsFixed(0)}')),
                    DropdownMenuItem(value: 'OTE', child: Text('OTE (One-Time Budget) - ₹${provider.oteBalance.toStringAsFixed(0)}')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _moneySource = (widget.defaultSource == MoneySource.PERSONAL) ? MoneySource.PERSONAL : MoneySource.ISKCON;
                      _derivedBudgetType = val == 'PME' ? BudgetType.PME : BudgetType.OTE;
                      _selectedCategoryName = null;
                      _selectedCategoryId = null;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),
              
              if (_moneySource == MoneySource.ISKCON || _moneySource == MoneySource.PERSONAL) ...[
                Text('CATEGORY', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Main Category'),
                  value: parentCategories.where((name) {
                    final catsInMain = allCats.where((c) => c.category == name && c.budgetType == _derivedBudgetType);
                    return catsInMain.isNotEmpty;
                  }).contains(_selectedCategoryName) ? _selectedCategoryName : null,
                  items: parentCategories.where((name) {
                    final catsInMain = allCats.where((c) => c.category == name && c.budgetType == _derivedBudgetType);
                    return catsInMain.isNotEmpty;
                  }).map<DropdownMenuItem<String?>>((name) {
                    double catTotal = allCats.where((c) => c.category == name && c.budgetType == _derivedBudgetType).fold(0, (sum, c) => sum + provider.getCategoryStatus(c)['remaining']!);
                    return DropdownMenuItem<String?>(value: name, child: Text('$name (₹${catTotal.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryName = val;
                      _selectedCategoryId = null;
                    });
                  },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Sub Category'),
                  value: filteredSubCats.where((c) => c.budgetType == _derivedBudgetType).any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                  items: filteredSubCats.where((c) => c.budgetType == _derivedBudgetType).map<DropdownMenuItem<String?>>((c) {
                    double rem = provider.getCategoryStatus(c)['remaining']!;
                    return DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text('${c.subCategory} (₹${rem.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryId = val;
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
                decoration: _inputDecoration('Amount').copyWith(
                    prefixText: '₹ ',
                    suffixText: _amountController.text.contains(RegExp(r'[+\s]')) ? '= ₹${_runningTotal.toStringAsFixed(0)}' : '',
                    suffixStyle: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)
                ),
                keyboardType: TextInputType.text, // To allow '+' or spaces
                onChanged: _updateRunningTotal,
                validator: (val) => (val == null || val.isEmpty || _runningTotal == 0) ? 'Required' : null,
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
              // Add extra padding at the bottom to ensure the last field is scrollable above the keyboard
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 40),
            ],
          ),
        ),
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
    // Check Category only if source is ISKCON OR PERSONAL
    if ((_moneySource == MoneySource.ISKCON || _moneySource == MoneySource.PERSONAL) && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    
    if (provider.activeCostCenterId == null) return;

    final String finalCatId = _selectedCategoryId!;
    final BudgetType finalBudgetType = _derivedBudgetType!;

    // Strict Rule: Check if expense exceeds category limit
    if (_moneySource == MoneySource.ISKCON) {
       try {
         final cat = provider.categories.firstWhere((c) => c.id == finalCatId);
         final status = provider.getCategoryStatus(cat);
         double remaining = status['remaining'] ?? 0.0;
         
         // If editing, add back the old amount IF it was the same category
         if (widget.expenseToEdit != null && widget.expenseToEdit!.categoryId == finalCatId) {
            remaining += widget.expenseToEdit!.amount;
         }

         if (_runningTotal > remaining) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Warning: Expense (₹${_runningTotal.toStringAsFixed(0)}) exceeds remaining budget (₹${remaining.toStringAsFixed(0)}) for ${cat.subCategory}. Proceeding anyway.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              )
            );
         }
       } catch (_) {
       }
    }

    final expense = Expense(
      id: widget.expenseToEdit?.id ?? const Uuid().v4(),
      costCenterId: provider.activeCostCenterId!,
      categoryId: finalCatId,
      amount: _runningTotal,
      budgetType: finalBudgetType,
      moneySource: _moneySource,
      date: _selectedDate,
      remarks: _remarksController.text,
      budgetMonth: null,
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
