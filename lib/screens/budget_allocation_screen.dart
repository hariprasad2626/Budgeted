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
  String _searchQuery = '';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Allocations', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 16),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filteredAllocs = provider.allocations.where((item) {
                        if (_searchQuery.isEmpty) return true;
                        final q = _searchQuery.toLowerCase();
                        return item.remarks.toLowerCase().contains(q) || item.budgetType.name.toLowerCase().contains(q);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredAllocs.length,
                        itemBuilder: (context, index) {
                          final item = filteredAllocs[index];
                          return ListTile(
                            title: Text('${item.budgetType.name}: ₹${item.amount}'),
                            subtitle: Text('${item.month ?? DateFormat('yyyy-MM-dd').format(item.date)} - ${item.remarks}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () => _confirmDelete(item),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BudgetAllocation item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Allocation?'),
        content: Text('Are you sure you want to delete this allocation of ₹${item.amount}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteAllocation(item);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Allocation deleted.')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
