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

  void _showAddDialog([CostCenter? center]) {
    if (center != null) {
      _name = center.name;
      _remarks = center.remarks;
      _defaultPme = center.defaultPmeAmount;
      _defaultOte = center.defaultOteAmount;
      _pmeStartMonth = center.pmeStartMonth;
    } else {
      _name = '';
      _remarks = '';
      _defaultPme = 0;
      _defaultOte = 0;
      _pmeStartMonth = '2026-01';
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
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => _name = val!,
                ),
                TextFormField(
                  initialValue: _defaultPme.toString(),
                  decoration: const InputDecoration(labelText: 'Monthly PME Budget (₹)'),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => _defaultPme = double.tryParse(val ?? '0') ?? 0,
                ),
                TextFormField(
                  initialValue: _defaultOte.toString(),
                  decoration: const InputDecoration(labelText: 'Total OTE Budget (₹)'),
                  keyboardType: TextInputType.number,
                  onSaved: (val) => _defaultOte = double.tryParse(val ?? '0') ?? 0,
                ),
                TextFormField(
                  initialValue: _pmeStartMonth,
                  decoration: const InputDecoration(labelText: 'PME Start Month (yyyy-MM)'),
                  onSaved: (val) => _pmeStartMonth = val ?? '2026-01',
                ),
                TextFormField(
                  initialValue: _remarks,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  onSaved: (val) => _remarks = val ?? '',
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
}
