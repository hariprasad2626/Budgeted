import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  String _searchQuery = '';
  final Set<String> _selectedCenterIds = {};
  bool _isSelectionMode = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedCenterIds.contains(id)) {
        _selectedCenterIds.remove(id);
        if (_selectedCenterIds.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedCenterIds.add(id);
      }
    });
  }

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
      appBar: AppBar(
        title: _isSearching
                ? TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search cost centers...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                    onChanged: (val) => setState(() => _searchQuery = val),
                  )
                : const Text('Manage Cost Centers'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
        ],
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          var centers = provider.costCenters;
          if (_searchQuery.isNotEmpty) {
            centers = centers.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.remarks.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          double selectedSum = centers
              .where((c) => _selectedCenterIds.contains(c.id))
              .fold(0.0, (sum, c) => sum + provider.getCostCenterBudgetBalance(c.id));

          return Column(
            children: [
              if (_isSelectionMode || _selectedCenterIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.teal.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: centers.isNotEmpty && centers.every((c) => _selectedCenterIds.contains(c.id)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedCenterIds.addAll(centers.map((c) => c.id));
                                  _isSelectionMode = true;
                                } else {
                                  _selectedCenterIds.clear();
                                  _isSelectionMode = false;
                                }
                              });
                            },
                            activeColor: Colors.tealAccent,
                          ),
                          const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                        ],
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Selected Balance Sum:', style: TextStyle(fontSize: 10, color: Colors.tealAccent)),
                              Text('₹${selectedSum.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                            onPressed: () => setState(() {
                              _selectedCenterIds.clear();
                              _isSelectionMode = false;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: centers.length,
                  itemBuilder: (context, index) {
                    final center = centers[index];
                    final isSelected = _selectedCenterIds.contains(center.id);
                    final balance = provider.getCostCenterBudgetBalance(center.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isSelected ? Colors.teal.withOpacity(0.1) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isSelected ? Colors.tealAccent : Colors.transparent),
                      ),
                      child: InkWell(
                        onLongPress: () => _toggleSelection(center.id),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(center.id);
                          } else {
                            provider.setActiveCostCenter(center.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Switched to ${center.name}')),
                            );
                          }
                        },
                        child: Column(
                          children: [
                            ListTile(
                              leading: _isSelectionMode ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(center.id),
                                activeColor: Colors.tealAccent,
                              ) : CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.business, color: Colors.teal)),
                              title: Text(center.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(center.remarks.isEmpty ? 'No remarks' : center.remarks),
                              trailing: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('₹${balance.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.greenAccent : Colors.redAccent)),
                                  const Text('Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
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
                                        activeColor: Colors.tealAccent,
                                      ),
                                      Text(center.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 11, color: center.isActive ? Colors.green : Colors.grey)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          provider.setActiveCostCenter(center.id);
                                          Navigator.pushNamed(context, '/manage-budget-periods');
                                        },
                                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                                        label: const Text('Budgets', style: TextStyle(fontSize: 12)),
                                        style: TextButton.styleFrom(foregroundColor: Colors.teal),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _showAddDialog(center),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
}
