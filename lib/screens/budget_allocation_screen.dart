import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/budget_allocation.dart';
import '../models/budget_category.dart';
import '../services/firestore_service.dart';

class BudgetAllocationScreen extends StatefulWidget {
  const BudgetAllocationScreen({super.key});

  @override
  State<BudgetAllocationScreen> createState() => _BudgetAllocationScreenState();
}

class _BudgetAllocationScreenState extends State<BudgetAllocationScreen> {
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  BudgetType _type = BudgetType.OTE;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget Allocation')),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<BudgetType>(
                  value: _type,
                  items: BudgetType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                  onChanged: (val) => setState(() => _type = val!),
                  decoration: const InputDecoration(labelText: 'Budget Type'),
                ),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹'),
                  keyboardType: TextInputType.number,
                ),
                ListTile(
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),
                TextField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_amountController.text.isEmpty) return;
                    
                    final activeId = provider.activeCostCenterId;
                    if (activeId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No active cost center selected.')),
                      );
                      return;
                    }

                    final allocation = BudgetAllocation(
                      id: '',
                      costCenterId: activeId,
                      budgetType: _type,
                      amount: double.parse(_amountController.text).abs(),
                      month: _type == BudgetType.PME ? DateFormat('yyyy-MM').format(_selectedDate) : null,
                      date: _selectedDate,
                      remarks: _remarksController.text,
                    );
                    await FirestoreService().addAllocation(allocation);
                    _amountController.clear();
                    _remarksController.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Allocation saved successfully!')),
                      );
                    }
                  },
                  child: const Text('Add Allocation'),
                ),
                const Divider(height: 32),
                const Text('Recent Allocations', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.allocations.length,
                    itemBuilder: (context, index) {
                      final item = provider.allocations[index];
                      return ListTile(
                        title: Text('${item.budgetType.name}: ₹${item.amount}'),
                        subtitle: Text('${item.month ?? DateFormat('yyyy-MM-dd').format(item.date)} - ${item.remarks}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
