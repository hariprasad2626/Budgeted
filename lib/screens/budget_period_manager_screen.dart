import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/budget_period.dart';
import '../services/firestore_service.dart';

class BudgetPeriodManagerScreen extends StatefulWidget {
  const BudgetPeriodManagerScreen({super.key});

  @override
  State<BudgetPeriodManagerScreen> createState() => _BudgetPeriodManagerScreenState();
}

class _BudgetPeriodManagerScreenState extends State<BudgetPeriodManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();
  
  String _name = '';
  String _startMonth = '';
  String _endMonth = '';
  double _defaultPme = 0;
  double _ote = 0;
  String _remarks = '';
  Map<String, double> _monthlyPme = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default to current fiscal year (April to March)
    final fiscalStartYear = now.month >= 4 ? now.year : now.year - 1;
    _startMonth = '$fiscalStartYear-04';
    _endMonth = '${fiscalStartYear + 1}-03';
  }

  void _showAddEditDialog([BudgetPeriod? period]) {
    final provider = context.read<AccountingProvider>();
    final center = provider.activeCostCenter;
    if (center == null) return;

    if (period != null) {
      _name = period.name;
      _startMonth = period.startMonth;
      _endMonth = period.endMonth;
      _defaultPme = period.defaultPmeAmount;
      _ote = period.oteAmount;
      _remarks = period.remarks;
      _monthlyPme = Map.from(period.monthlyPme);
    } else {
      final now = DateTime.now();
      final fiscalStartYear = now.month >= 4 ? now.year : now.year - 1;
      _name = 'FY ${fiscalStartYear}-${(fiscalStartYear + 1) % 100}';
      _startMonth = '$fiscalStartYear-04';
      _endMonth = '${fiscalStartYear + 1}-03';
      _defaultPme = center.defaultPmeAmount;
      _ote = center.defaultOteAmount;
      _remarks = '';
      _monthlyPme = {};
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(period == null ? 'Add Budget Period' : 'Edit Budget Period'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: _name,
                      decoration: const InputDecoration(
                        labelText: 'Period Name',
                        hintText: 'e.g., FY 2025-26',
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      onSaved: (val) => _name = val!,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _startMonth,
                            decoration: const InputDecoration(
                              labelText: 'Start Month',
                              hintText: 'yyyy-MM',
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(val)) return 'Format: yyyy-MM';
                              return null;
                            },
                            onChanged: (val) {
                              setDialogState(() => _startMonth = val);
                            },
                            onSaved: (val) => _startMonth = val!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _endMonth,
                            decoration: const InputDecoration(
                              labelText: 'End Month',
                              hintText: 'yyyy-MM',
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(val)) return 'Format: yyyy-MM';
                              return null;
                            },
                            onChanged: (val) {
                              setDialogState(() => _endMonth = val);
                            },
                            onSaved: (val) => _endMonth = val!,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _defaultPme.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Default Monthly PME (₹)',
                        hintText: 'Applied to all months by default',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setDialogState(() => _defaultPme = double.tryParse(val) ?? 0);
                      },
                      onSaved: (val) => _defaultPme = double.tryParse(val ?? '0') ?? 0,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _ote.toString(),
                      decoration: const InputDecoration(
                        labelText: 'OTE Budget (₹)',
                        hintText: 'One-time expense for this period',
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (val) => _ote = double.tryParse(val ?? '0') ?? 0,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _remarks,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                      maxLines: 2,
                      onSaved: (val) => _remarks = val ?? '',
                    ),
                    // Monthly PME customization section (Compact & Expandable)
                    const Divider(height: 32),
                    ExpansionTile(
                      title: const Text('Adjust Individual Months', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Optional overrides for specific months', style: TextStyle(fontSize: 12)),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        _buildMonthlyPmeSection(setDialogState),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _savePeriod(period, center.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(period == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthlyPmeSection(StateSetter setDialogState) {
    // Generate list of months between start and end
    List<String> months = [];
    try {
      final startParts = _startMonth.split('-');
      final endParts = _endMonth.split('-');
      
      if (startParts.length == 2 && endParts.length == 2) {
        int startYear = int.parse(startParts[0]);
        int startMon = int.parse(startParts[1]);
        int endYear = int.parse(endParts[0]);
        int endMon = int.parse(endParts[1]);

        int currentYear = startYear;
        int currentMon = startMon;

        while (currentYear < endYear || (currentYear == endYear && currentMon <= endMon)) {
          months.add('$currentYear-${currentMon.toString().padLeft(2, '0')}');
          currentMon++;
          if (currentMon > 12) {
            currentMon = 1;
            currentYear++;
          }
        }
      }
    } catch (e) {
      // Invalid date format
    }

    if (months.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Enter valid start and end months to see monthly breakdown', 
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    double totalPme = 0;
    for (var month in months) {
      totalPme += _monthlyPme[month] ?? _defaultPme;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${months.length} months total', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Total PME: ₹${NumberFormat('#,##,###').format(totalPme)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: months.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) {
              final month = months[index];
              final hasOverride = _monthlyPme.containsKey(month);
              final amount = _monthlyPme[month] ?? _defaultPme;
              
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(_formatMonth(month), style: const TextStyle(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${NumberFormat('#,##,###').format(amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: hasOverride ? Colors.orange : null,
                        fontWeight: hasOverride ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    IconButton(
                      icon: Icon(hasOverride ? Icons.edit : Icons.add, size: 16),
                      onPressed: () => _editMonthAmount(month, amount, setDialogState),
                    ),
                    if (hasOverride)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                        onPressed: () {
                          setDialogState(() => _monthlyPme.remove(month));
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatMonth(String month) {
    try {
      final date = DateFormat('yyyy-MM').parse(month);
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      return month;
    }
  }

  void _editMonthAmount(String month, double currentAmount, StateSetter setDialogState) {
    final controller = TextEditingController(text: currentAmount.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_formatMonth(month)}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'PME Amount (₹)',
            hintText: 'Default: ₹${_defaultPme}',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(controller.text) ?? _defaultPme;
              setDialogState(() {
                if (newAmount != _defaultPme) {
                  _monthlyPme[month] = newAmount;
                } else {
                  _monthlyPme.remove(month);
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePeriod(BudgetPeriod? existingPeriod, String costCenterId) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final period = BudgetPeriod(
      id: existingPeriod?.id ?? '',
      costCenterId: costCenterId,
      name: _name,
      startMonth: _startMonth,
      endMonth: _endMonth,
      defaultPmeAmount: _defaultPme,
      monthlyPme: _monthlyPme,
      oteAmount: _ote,
      createdAt: existingPeriod?.createdAt ?? DateTime.now(),
      isActive: existingPeriod?.isActive ?? true,
      remarks: _remarks,
    );

    try {
      if (existingPeriod == null) {
        await _service.addBudgetPeriod(period);
      } else {
        await _service.updateBudgetPeriod(period);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget period ${existingPeriod == null ? 'added' : 'updated'}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(BudgetPeriod period) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget Period?'),
        content: Text('Are you sure you want to delete "${period.name}"?\n\nThis will affect budget calculations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _service.deleteBudgetPeriod(period.id);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Budget period deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Periods'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Budget Periods'),
                  content: const Text(
                    'Budget periods allow you to define yearly budget cycles with:\n\n'
                    '• Start and end months (e.g., April to March)\n'
                    '• Default monthly PME amount\n'
                    '• Per-month customization (reduce specific months)\n'
                    '• One-time expense (OTE) budget\n\n'
                    'Multiple periods can overlap - their budgets stack/add together.\n\n'
                    'This is useful for managing yearly budget cycles and carryover funds.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final center = provider.activeCostCenter;
          if (center == null) {
            return const Center(child: Text('No cost center selected'));
          }

          final periods = provider.budgetPeriods;
          
          if (periods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No budget periods defined', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                    'Currently using cost center defaults:\nPME: ₹${NumberFormat('#,##,###').format(center.defaultPmeAmount)}/mo\nOTE: ₹${NumberFormat('#,##,###').format(center.defaultOteAmount)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Budget Period'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                ],
              ),
            );
          }

          // Calculate totals
          double totalPme = provider.budgetPeriods
              .where((p) => p.isActive)
              .fold(0.0, (sum, p) => sum + p.totalPmeBudget);
          double totalOte = provider.budgetPeriods
              .where((p) => p.isActive)
              .fold(0.0, (sum, p) => sum + p.oteAmount);

          return Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Total PME Budget', style: TextStyle(color: Colors.white70)),
                        Text('₹${NumberFormat('#,##,###').format(totalPme)}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    Column(
                      children: [
                        const Text('Total OTE Budget', style: TextStyle(color: Colors.white70)),
                        Text('₹${NumberFormat('#,##,###').format(totalOte)}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Periods List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: periods.length,
                  itemBuilder: (context, index) {
                    final period = periods[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: period.isActive ? Colors.teal : Colors.grey,
                          child: Icon(
                            period.isActive ? Icons.check : Icons.pause,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(period.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${_formatMonth(period.startMonth)} → ${_formatMonth(period.endMonth)} (${period.monthCount} months)\n'
                          'PME: ₹${NumberFormat('#,##,###').format(period.totalPmeBudget)} | OTE: ₹${NumberFormat('#,##,###').format(period.oteAmount)}',
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(period.isActive ? 'Deactivate' : 'Activate'),
                            ),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showAddEditDialog(period);
                            } else if (value == 'toggle') {
                              await _service.updateBudgetPeriod(
                                period.copyWith(isActive: !period.isActive),
                              );
                            } else if (value == 'delete') {
                              _confirmDelete(period);
                            }
                          },
                        ),
                        children: [
                          // Monthly breakdown
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monthly PME Breakdown:', 
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: period.getAllMonths().map((month) {
                                    final amount = period.getPmeForMonth(month);
                                    final hasOverride = period.monthlyPme.containsKey(month);
                                    return Chip(
                                      label: Text(
                                        '${_formatMonth(month)}: ₹${NumberFormat('#,##,###').format(amount)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: hasOverride ? Colors.orange.shade800 : null,
                                        ),
                                      ),
                                      backgroundColor: hasOverride ? Colors.orange.shade100 : null,
                                    );
                                  }).toList(),
                                ),
                                if (period.remarks.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text('Remarks: ${period.remarks}', 
                                    style: const TextStyle(color: Colors.grey)),
                                ],
                              ],
                            ),
                          ),
                        ],
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
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
