import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/fund_transfer.dart';
import '../models/budget_category.dart';
import '../services/firestore_service.dart';

class AddTransferScreen extends StatefulWidget {
  final FundTransfer? transferToEdit;
  final TransferType? initialType;
  const AddTransferScreen({super.key, this.transferToEdit, this.initialType});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String? _selectedCostCenterId;
  DateTime _selectedDate = DateTime.now();
  TransferType _type = TransferType.TO_PERSONAL;
  
  // Selection state for FROM
  String? _fromCategoryName;
  String? _fromCategoryId;
  
  // Selection state for TO
  String? _toCategoryName;
  String? _toCategoryId;
  
  String? _targetMonth;

  @override
  void initState() {
    super.initState();
    if (widget.transferToEdit != null) {
      final t = widget.transferToEdit!;
      _amountController.text = t.amount.toString();
      _remarksController.text = t.remarks;
      _selectedCostCenterId = t.costCenterId;
      _selectedDate = t.date;
      _type = t.type;
      _fromCategoryId = t.fromCategoryId;
      _toCategoryId = t.toCategoryId;
      _targetMonth = t.targetMonth;
      
      // We'll resolve category names in build() or after first frame
    } else {
      _type = widget.initialType ?? TransferType.TO_PERSONAL;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = Provider.of<AccountingProvider>(context, listen: false);
        setState(() {
          _selectedCostCenterId = provider.activeCostCenterId;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final allCats = provider.categories;

    // Resolve initial names if editing
    if (widget.transferToEdit != null) {
      if (_fromCategoryId != null && _fromCategoryName == null) {
        try {
          _fromCategoryName = allCats.firstWhere((c) => c.id == _fromCategoryId).category;
        } catch (_) {}
      }
      if (_toCategoryId != null && _toCategoryName == null) {
        try {
          _toCategoryName = allCats.firstWhere((c) => c.id == _toCategoryId).category;
        } catch (_) {}
      }
    }

    final parentCategories = allCats.map((c) => c.category).toSet().toList()..sort();
    
    final fromSubCats = _fromCategoryName == null ? <BudgetCategory>[] : allCats.where((c) => c.category == _fromCategoryName).toList();
    final toSubCats = _toCategoryName == null ? <BudgetCategory>[] : allCats.where((c) => c.category == _toCategoryName).toList();

    // Determine if any selected category is PME
    bool isPme = false;
    if (_fromCategoryId != null) {
      if (allCats.any((c) => c.id == _fromCategoryId && c.budgetType == BudgetType.PME)) isPme = true;
    }
    if (_toCategoryId != null) {
      if (allCats.any((c) => c.id == _toCategoryId && c.budgetType == BudgetType.PME)) isPme = true;
    }

    final availableMonths = provider.budgetPeriods
        .where((p) => p.isActive)
        .expand((p) => p.getAllMonths())
        .toSet()
        .toList()
        ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transferToEdit == null ? 'Fund Transfer' : 'Edit Transfer'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_type == TransferType.TO_PERSONAL) ...[
                Text('RECORD ADVANCE', style: _labelStyle),
                const SizedBox(height: 16),
                Text('SOURCE COST CENTER', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Select Center'),
                  value: _selectedCostCenterId,
                  items: provider.costCenters.map<DropdownMenuItem<String?>>((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) => setState(() => _selectedCostCenterId = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
              ] else ...[
                 Text('INTERNAL TRANSFER', style: _labelStyle),
                 const SizedBox(height: 16),
                // --- FROM SECTION ---
                Text('FROM (SOURCE)', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Main Category / Wallet'),
                  value: _fromCategoryName,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null, 
                      child: Text('General Wallet / Unallocated (₹${provider.walletBalance.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))
                    ),
                    ...parentCategories.map<DropdownMenuItem<String?>>((name) {
                      double catTotal = allCats.where((c) => c.category == name).fold(0, (sum, c) => sum + provider.getCategoryStatus(c)['remaining']!);
                      return DropdownMenuItem<String?>(value: name, child: Text('$name (₹${catTotal.toStringAsFixed(0)})'));
                    }),
                  ],
                  onChanged: (val) => setState(() {
                    _fromCategoryName = val;
                    _fromCategoryId = null; // Reset sub-selection
                  }),
                ),
                if (_fromCategoryName != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: _inputDecoration('Sub Category'),
                    value: fromSubCats.any((c) => c.id == _fromCategoryId) ? _fromCategoryId : null,
                    items: fromSubCats.map<DropdownMenuItem<String?>>((c) {
                      double rem = provider.getCategoryStatus(c)['remaining']!;
                      return DropdownMenuItem<String?>(value: c.id, child: Text('${c.subCategory} (₹${rem.toStringAsFixed(0)})'));
                    }).toList(),
                    onChanged: (val) => setState(() => _fromCategoryId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                ],
                
                const SizedBox(height: 24),
                // --- TO SECTION ---
                Text('TO (DESTINATION)', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Main Category / Wallet'),
                  value: _toCategoryName,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null, 
                      child: Text('General Wallet / Unallocated (₹${provider.walletBalance.toStringAsFixed(0)})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))
                    ),
                    ...parentCategories.map<DropdownMenuItem<String?>>((name) {
                      double catTotal = allCats.where((c) => c.category == name).fold(0, (sum, c) => sum + provider.getCategoryStatus(c)['remaining']!);
                      return DropdownMenuItem<String?>(value: name, child: Text('$name (₹${catTotal.toStringAsFixed(0)})'));
                    }),
                  ],
                  onChanged: (val) => setState(() {
                    _toCategoryName = val;
                    _toCategoryId = null; // Reset sub-selection
                  }),
                ),
                if (_toCategoryName != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    decoration: _inputDecoration('Sub Category'),
                    value: toSubCats.any((c) => c.id == _toCategoryId) ? _toCategoryId : null,
                    items: toSubCats.map<DropdownMenuItem<String?>>((c) {
                      double rem = provider.getCategoryStatus(c)['remaining']!;
                      return DropdownMenuItem<String?>(value: c.id, child: Text('${c.subCategory} (₹${rem.toStringAsFixed(0)})'));
                    }).toList(),
                    onChanged: (val) => setState(() => _toCategoryId = val),
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                ],
              ],

              if (_type == TransferType.CATEGORY_TO_CATEGORY && isPme) ...[
                const SizedBox(height: 24),
                Text('TARGET MONTH (FOR PME)', style: _labelStyle),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: _inputDecoration('Select Month (Optional)'),
                  value: _targetMonth,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null, 
                      child: Text('All Months/General (Default)', style: TextStyle(color: Colors.grey))
                    ),
                    ...availableMonths.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(m))),
                    )),
                  ],
                  onChanged: (val) => setState(() => _targetMonth = val),
                ),
              ],
              
              const SizedBox(height: 24),
              Text('TRANSFER DETAILS', style: _labelStyle),
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
                decoration: _inputDecoration('Remarks / Transfer Note'),
                maxLines: 2,
                validator: (val) => (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _type == TransferType.TO_PERSONAL ? Colors.blue.shade700 : Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: Text(
                    widget.transferToEdit == null ? 'RECORD TRANSFER' : 'UPDATE TRANSFER',
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
            widget.transferToEdit == null ? 'Fund Transfer' : 'Edit Transfer',
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
    color: _type == TransferType.TO_PERSONAL ? Colors.blue.shade700 : Colors.teal.shade700,
    letterSpacing: 1.1,
  );

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
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

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check circular or same source/dest
    if (_type == TransferType.CATEGORY_TO_CATEGORY && _fromCategoryId == _toCategoryId && _fromCategoryName == _toCategoryName) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and Destination cannot be identical')));
       return;
    }

    final provider = Provider.of<AccountingProvider>(context, listen: false);

    final transfer = FundTransfer(
      id: widget.transferToEdit?.id ?? const Uuid().v4(),
      costCenterId: _selectedCostCenterId ?? provider.activeCostCenterId ?? '',
      amount: double.parse(_amountController.text).abs(),
      date: _selectedDate,
      remarks: _remarksController.text,
      type: _type,
      fromCategoryId: _fromCategoryId,
      toCategoryId: _toCategoryId,
      targetMonth: _targetMonth,
    );

    if (widget.transferToEdit == null) {
      await FirestoreService().addFundTransfer(transfer);
    } else {
      await FirestoreService().updateFundTransfer(transfer);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
