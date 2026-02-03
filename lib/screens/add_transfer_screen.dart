import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/fund_transfer.dart';
import '../services/firestore_service.dart';

class AddTransferScreen extends StatefulWidget {
  final FundTransfer? transferToEdit;
  const AddTransferScreen({super.key, this.transferToEdit});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String? _selectedCostCenterId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.transferToEdit != null) {
      final t = widget.transferToEdit!;
      _amountController.text = t.amount.toString();
      _remarksController.text = t.remarks;
      _selectedCostCenterId = t.costCenterId;
      _selectedDate = t.date;
    } else {
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
                    const Text(
                      'Move funds from Cost Center to Personal Account as an advance.',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Text('SOURCE', style: _labelStyle),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration('Source Cost Center'),
                      value: _selectedCostCenterId,
                      items: provider.costCenters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (val) => setState(() => _selectedCostCenterId = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
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
                          backgroundColor: Colors.blue.shade700,
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
            widget.transferToEdit == null ? 'ISKCON Transfer' : 'Edit Transfer',
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
    color: Colors.blue.shade700,
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

    final transfer = FundTransfer(
      id: widget.transferToEdit?.id ?? const Uuid().v4(),
      costCenterId: _selectedCostCenterId!,
      amount: double.parse(_amountController.text).abs(),
      date: _selectedDate,
      remarks: _remarksController.text,
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
