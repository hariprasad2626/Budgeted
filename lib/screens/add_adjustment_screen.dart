import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/personal_adjustment.dart';
import '../services/firestore_service.dart';

class AddAdjustmentScreen extends StatefulWidget {
  final PersonalAdjustment? adjustmentToEdit;
  const AddAdjustmentScreen({super.key, this.adjustmentToEdit});

  @override
  State<AddAdjustmentScreen> createState() => _AddAdjustmentScreenState();
}

class _AddAdjustmentScreenState extends State<AddAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  AdjustmentType _type = AdjustmentType.DEBIT;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.adjustmentToEdit != null) {
      final adj = widget.adjustmentToEdit!;
      _amountController.text = adj.amount.toString();
      _remarksController.text = adj.remarks;
      _type = adj.type;
      _selectedDate = adj.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adjustmentToEdit == null ? 'Personal Expense Entry' : 'Edit Personal Entry'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TYPE', style: _labelStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<AdjustmentType>(
                decoration: _inputDecoration('Entry Type'),
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
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _submit,
                  child: Text(
                    widget.adjustmentToEdit == null ? 'SAVE ENTRY' : 'UPDATE ENTRY',
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
            widget.adjustmentToEdit == null ? 'Personal Expense Entry' : 'Edit Personal Entry',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    color: Colors.teal.shade700,
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

    final adjustment = PersonalAdjustment(
      id: widget.adjustmentToEdit?.id ?? const Uuid().v4(),
      type: _type,
      amount: double.parse(_amountController.text).abs(),
      date: _selectedDate,
      remarks: _remarksController.text,
    );

    if (widget.adjustmentToEdit == null) {
      await FirestoreService().addPersonalAdjustment(adjustment);
    } else {
      await FirestoreService().updatePersonalAdjustment(adjustment);
    }
    
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
