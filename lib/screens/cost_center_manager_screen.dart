import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/cost_center.dart';
import '../services/firestore_service.dart';

class CostCenterManagerScreen extends StatefulWidget {
  const CostCenterManagerScreen({super.key});

  @override
  State<CostCenterManagerScreen> createState() => _CostCenterManagerScreenState();
}

class _CostCenterManagerScreenState extends State<CostCenterManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _remarks = '';
  double _defaultPme = 0;
  double _defaultOte = 0;
  String _pmeStartMonth = '2026-01';
  String _pmeEndMonth = '2026-12';

  void _showAddDialog([CostCenter? center]) {
    if (center != null) {
      _name = center.name;
      _remarks = center.remarks;
      _defaultPme = center.defaultPmeAmount;
      _defaultOte = center.defaultOteAmount;
      _pmeStartMonth = center.pmeStartMonth;
      _pmeEndMonth = center.pmeEndMonth;
    } else {
      _name = '';
      _remarks = '';
      _defaultPme = 0;
      _defaultOte = 0;
      _pmeStartMonth = '2026-01';
      _pmeEndMonth = '2026-12';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center == null ? 'Add Cost Center' : 'Edit Cost Center'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRefinedField('Cost Center Name', _name, (val) => _name = val!, Icons.business),
                const SizedBox(height: 16),
                _buildRefinedField('Remarks', _remarks, (val) => _remarks = val!, Icons.notes, maxLines: 2),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Budget values are managed per period in the "Manage Budgets" section.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final newCenter = CostCenter(
                  id: center?.id ?? '',
                  name: _name,
                  isActive: center?.isActive ?? true,
                  createdAt: center?.createdAt ?? DateTime.now(),
                  remarks: _remarks,
                  defaultPmeAmount: _defaultPme,
                  defaultOteAmount: _defaultOte,
                  pmeStartMonth: _pmeStartMonth,
                  pmeEndMonth: _pmeEndMonth,
                );
                final service = FirestoreService();
                String action = center == null ? 'added' : 'updated';
                if (center == null) {
                  await service.addCostCenter(newCenter);
                } else {
                  await service.updateCostCenter(newCenter);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Cost Center $action successfully!')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Cost Centers')),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final centers = provider.costCenters;
          return ListView.builder(
            itemCount: centers.length,
            itemBuilder: (context, index) {
              final center = centers[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(center.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(center.remarks.isEmpty ? 'No remarks' : center.remarks),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: center.isActive,
                            onChanged: (val) {
                              final updated = CostCenter(
                                id: center.id,
                                name: center.name,
                                isActive: val,
                                createdAt: center.createdAt,
                                remarks: center.remarks,
                                defaultPmeAmount: center.defaultPmeAmount,
                                defaultOteAmount: center.defaultOteAmount,
                                pmeStartMonth: center.pmeStartMonth,
                                pmeEndMonth: center.pmeEndMonth,
                              );
                              FirestoreService().updateCostCenter(updated);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showAddDialog(center),
                          ),
                        ],
                      ),
                      onTap: () {
                        provider.setActiveCostCenter(center.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switched to ${center.name}')),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Budget Periods', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          TextButton.icon(
                            onPressed: () {
                              provider.setActiveCostCenter(center.id);
                              Navigator.pushNamed(context, '/manage-budget-periods');
                            },
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                            label: const Text('Manage Budgets'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.teal,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
  Widget _buildRefinedField(String label, String initial, FormFieldSetter<String> onSaved, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.teal.withOpacity(0.05),
      ),
      maxLines: maxLines,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildRefinedNumberField(String label, double initial, Function(double) onSaved) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initial.toString(),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.currency_rupee, size: 20, color: Colors.teal),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onSaved: (val) => onSaved(double.tryParse(val ?? '0') ?? 0),
      ),
    );
  }
}
