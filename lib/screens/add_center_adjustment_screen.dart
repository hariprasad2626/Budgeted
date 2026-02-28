import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/cost_center_adjustment.dart';
import '../models/personal_adjustment.dart'; // For AdjustmentType
import '../models/budget_category.dart';
import '../services/firestore_service.dart';

class AddCenterAdjustmentScreen extends StatefulWidget {
  final CostCenterAdjustment? adjustmentToEdit;
  const AddCenterAdjustmentScreen({super.key, this.adjustmentToEdit});

  @override
  State<AddCenterAdjustmentScreen> createState() => _AddCenterAdjustmentScreenState();
}

class _AddCenterAdjustmentScreenState extends State<AddCenterAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  AdjustmentType _type = AdjustmentType.DEBIT;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  BudgetType? _derivedBudgetType;

  @override
  void initState() {
    super.initState();
    if (widget.adjustmentToEdit != null) {
      final adj = widget.adjustmentToEdit!;
      _amountController.text = adj.amount.toString();
      _remarksController.text = adj.remarks;
      _type = adj.type;
      _selectedCategoryId = adj.categoryId;
      _selectedDate = adj.date;
      _derivedBudgetType = adj.budgetType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final categories = provider.categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adjustmentToEdit == null ? 'Cost Center Adjustment' : 'Edit Adjustment'),
        backgroundColor: Colors.orange.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BUDGET POOL', style: _labelStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Select Pool'),
                value: _selectedCategoryId == null && _derivedBudgetType == null ? null : (_derivedBudgetType?.toString().split('.').last ?? 'PME'),
                items: const [
                  DropdownMenuItem(value: 'PME', child: Text('PME (Monthly)')),
                  DropdownMenuItem(value: 'OTE', child: Text('OTE (One-Time)')),
                  DropdownMenuItem(value: 'WALLET', child: Text('Master Wallet')),
                ],
                onChanged: (val) {
                  setState(() {
                    if (val == 'WALLET') {
                      _derivedBudgetType = null;
                      _selectedCategoryId = ''; // Empty string in your model seems to mean No Category
                    } else {
                      _derivedBudgetType = val == 'PME' ? BudgetType.PME : BudgetType.OTE;
                      _selectedCategoryId = null; // Forces re-selection
                    }
                  });
                },
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              if (_derivedBudgetType != null) ...[
                Text('TARGET CATEGORY', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _inputDecoration('Select Sub-Category'),
                  value: categories.where((c) => c.budgetType == _derivedBudgetType).any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                  items: categories.where((c) => c.budgetType == _derivedBudgetType).map((c) => DropdownMenuItem(
                    value: c.id, 
                    child: Text(
                      '${c.category} - ${c.subCategory}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    )
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryId = val;
                    });
                  },
                  validator: (val) => val == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
              ],
              Text('ADJUSTMENT TYPE', style: _labelStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<AdjustmentType>(
                decoration: _inputDecoration('Type'),
                value: _type,
                items: AdjustmentType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.toString().split('.').last))).toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
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
                decoration: _inputDecoration('Remarks / Descr.'),
                maxLines: 2,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: Text(
                    widget.adjustmentToEdit == null ? 'SAVE CENTER ADJUSTMENT' : 'UPDATE ADJUSTMENT',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
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
          const Text('Cost Center Adjustment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  TextStyle get _labelStyle => TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800, letterSpacing: 1.1);
  InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    if (provider.activeCostCenterId == null) return;

    final adjustment = CostCenterAdjustment(
      id: widget.adjustmentToEdit?.id ?? const Uuid().v4(),
      costCenterId: provider.activeCostCenterId!,
      categoryId: _selectedCategoryId!,
      type: _type,
      amount: double.parse(_amountController.text).abs(),
      date: _selectedDate,
      remarks: _remarksController.text,
      budgetType: _derivedBudgetType!,
    );

    if (widget.adjustmentToEdit == null) {
      await FirestoreService().addCostCenterAdjustment(adjustment);
    } else {
      await FirestoreService().updateCostCenterAdjustment(adjustment);
    }
    
    if (mounted) Navigator.pop(context);
  }
}
