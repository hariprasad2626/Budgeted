import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/accounting_provider.dart';
import '../models/donation.dart';
import '../services/firestore_service.dart';

class AddDonationScreen extends StatefulWidget {
  final Donation? donationToEdit;
  const AddDonationScreen({super.key, this.donationToEdit});

  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  DonationMode _mode = DonationMode.WALLET;
  String? _selectedCategoryName;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.donationToEdit != null) {
      final d = widget.donationToEdit!;
      _amountController.text = d.amount.toString();
      _remarksController.text = d.remarks;
      _mode = d.mode;
      _selectedCategoryId = d.budgetCategoryId;
      _selectedDate = d.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AccountingProvider>(context);
    final allCats = provider.categories;

    if (widget.donationToEdit != null && _selectedCategoryName == null && _selectedCategoryId != null) {
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
                    DropdownButtonFormField<DonationMode>(
                      isExpanded: true,
                      decoration: _inputDecoration('Donation Mode'),
                      value: _mode,
                      items: DonationMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.toString().split('.').last, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _mode = val!),
                    ),
                    const SizedBox(height: 16),
                    if (_mode == DonationMode.MERGE_TO_BUDGET) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: _inputDecoration('Target Category'),
                        value: parentCategories.contains(_selectedCategoryName) ? _selectedCategoryName : null,
                        items: parentCategories.map((name) => DropdownMenuItem(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() {
                          _selectedCategoryName = val;
                          _selectedCategoryId = null;
                        }),
                        validator: (val) => (_mode == DonationMode.MERGE_TO_BUDGET && val == null) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: _inputDecoration('Sub Category'),
                        value: filteredSubCats.any((c) => c.id == _selectedCategoryId) ? _selectedCategoryId : null,
                        items: filteredSubCats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.subCategory, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                        validator: (val) => (_mode == DonationMode.MERGE_TO_BUDGET && val == null) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
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
                      decoration: _inputDecoration('Remarks / Source'),
                      maxLines: 2,
                      validator: (val) => (val == null || val.isEmpty) ? 'Remarks are mandatory' : null,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          widget.donationToEdit == null ? 'SAVE DONATION' : 'UPDATE DONATION',
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
            widget.donationToEdit == null ? 'New Donation' : 'Edit Donation',
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
    color: Colors.green.shade700,
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
    
    final provider = Provider.of<AccountingProvider>(context, listen: false);
    if (provider.activeCostCenterId == null) return;

    final donation = Donation(
      id: widget.donationToEdit?.id ?? const Uuid().v4(),
      costCenterId: provider.activeCostCenterId!,
      amount: double.parse(_amountController.text).abs(),
      mode: _mode,
      budgetCategoryId: _mode == DonationMode.MERGE_TO_BUDGET ? _selectedCategoryId : null,
      date: _selectedDate,
      remarks: _remarksController.text,
    );

    if (widget.donationToEdit == null) {
      await FirestoreService().addDonation(donation);
    } else {
      await FirestoreService().updateDonation(donation);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
