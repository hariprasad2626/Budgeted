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
  Map<String, String> _monthlyPmeRemarks = {};

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
      _monthlyPmeRemarks = Map.from(period.monthlyPmeRemarks);
    } else {
      // SMART DEFAULTING
      final periods = Provider.of<AccountingProvider>(context, listen: false).budgetPeriods;
      if (periods.isNotEmpty) {
        // Sort to find the absolutely last end month
        final sortedPeriods = List<BudgetPeriod>.from(periods)..sort((a, b) => b.endMonth.compareTo(a.endMonth));
        final lastEndMonth = sortedPeriods.first.endMonth;
        
        try {
          final lastDate = DateFormat('yyyy-MM').parse(lastEndMonth);
          final nextStartDate = DateTime(lastDate.year, lastDate.month + 1, 1);
          final nextEndDate = DateTime(nextStartDate.year, nextStartDate.month + 11, 1);
          
          _startMonth = DateFormat('yyyy-MM').format(nextStartDate);
          _endMonth = DateFormat('yyyy-MM').format(nextEndDate);
          _name = 'Allocation ${DateFormat('MMM yy').format(nextStartDate)} - ${DateFormat('MMM yy').format(nextEndDate)}';

          // Carry forward amounts from last period
          _defaultPme = sortedPeriods.first.defaultPmeAmount;
          _ote = sortedPeriods.first.oteAmount;
        } catch (_) {
          _startMonth = center.pmeStartMonth;
          _endMonth = center.pmeEndMonth;
          _name = 'New Budget Cycle';
          _defaultPme = 0;
          _ote = 0;
        }
      } else {
        // No periods yet
        _startMonth = center.pmeStartMonth;
        _endMonth = center.pmeEndMonth;
        _name = 'Initial Budget Cycle';
        _defaultPme = 0;
        _ote = 0;
      }
      
      _remarks = '';
      _monthlyPme = {};
      _monthlyPmeRemarks = {};
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
                    _buildTextField('Period Name', _name, (String? val) { _name = val ?? ''; }),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildMonthPicker('Start Month', _startMonth, (String val) => setDialogState(() { _startMonth = val; }))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMonthPicker('End Month', _endMonth, (String val) => setDialogState(() { _endMonth = val; }))),
                      ],
                    ),
                    const Divider(height: 32),
                    
                    // The two main components: PME and OTE
                    const Text('Budget Components', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                    const SizedBox(height: 16),
                    
                    // PME Section
                    _buildNumberField('Default Monthly PME (₹)', _defaultPme, (double val) => setDialogState(() { _defaultPme = val; })),
                    ExpansionTile(
                      title: const Text('Monthly PME Overrides', style: TextStyle(fontSize: 14)),
                      subtitle: Text('${_monthlyPme.length} overrides applied', style: const TextStyle(fontSize: 12)),
                      tilePadding: EdgeInsets.zero,
                      children: [_buildMonthlyPmeSection(setDialogState)],
                    ),
                    const SizedBox(height: 16),
                    
                    // OTE Section
                    _buildNumberField('One-Time Expense (OTE) (₹)', _ote, (double val) { _ote = val; }),
                    
                    const SizedBox(height: 16),
                    _buildTextField('Remarks', _remarks, (String? val) { _remarks = val ?? ''; }, maxLines: 2),
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
          child: SingleChildScrollView(
            child: Column(
              children: months.map((month) {
            final hasOverride = _monthlyPme.containsKey(month);
            final amount = _monthlyPme[month] ?? _defaultPme;
            
            return Column(
              children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(_formatMonth(month), style: const TextStyle(fontSize: 13)),
                  subtitle: _monthlyPmeRemarks.containsKey(month) 
                    ? Text(_monthlyPmeRemarks[month]!, style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic))
                    : null,
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
                            setDialogState(() {
                              _monthlyPme.remove(month);
                              _monthlyPmeRemarks.remove(month);
                            });
                          },
                        ),
                    ],
                  ),
                ),
                ],
              );
            }).toList(),
          ),
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
    final amountController = TextEditingController(text: currentAmount.toString());
    final remarkController = TextEditingController(text: _monthlyPmeRemarks[month] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_formatMonth(month)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PME Amount (₹)',
                hintText: 'Default: ₹${_defaultPme}',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: 'Remarks for this month',
                hintText: 'e.g., Reduced due to surplus',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newAmount = double.tryParse(amountController.text) ?? _defaultPme;
              final newRemark = remarkController.text.trim();
              setDialogState(() {
                if (newAmount != _defaultPme) {
                  _monthlyPme[month] = newAmount;
                } else {
                  _monthlyPme.remove(month);
                }

                if (newRemark.isNotEmpty) {
                  _monthlyPmeRemarks[month] = newRemark;
                } else {
                  _monthlyPmeRemarks.remove(month);
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
      monthlyPmeRemarks: _monthlyPmeRemarks,
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

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(
            '₹${NumberFormat('#,##,###').format(amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.teal.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  void _editMonthAmountFromList(BudgetPeriod period, String month, double currentAmount) {
    final amountController = TextEditingController(text: currentAmount.toString());
    final remarkController = TextEditingController(text: period.monthlyPmeRemarks[month] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${_formatMonth(month)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'PME Amount (₹)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: 'Remarks for this month'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text) ?? period.defaultPmeAmount;
              final newRemark = remarkController.text.trim();
              
              final updatedMonthlyPme = Map<String, double>.from(period.monthlyPme);
              final updatedRemarks = Map<String, String>.from(period.monthlyPmeRemarks);
              
              if (newAmount != period.defaultPmeAmount) {
                updatedMonthlyPme[month] = newAmount;
              } else {
                updatedMonthlyPme.remove(month);
              }

              if (newRemark.isNotEmpty) {
                updatedRemarks[month] = newRemark;
              } else {
                updatedRemarks.remove(month);
              }

              await _service.updateBudgetPeriod(period.copyWith(
                monthlyPme: updatedMonthlyPme,
                monthlyPmeRemarks: updatedRemarks,
              ));
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String initial, FormFieldSetter<String> onSaved, {int maxLines = 1}) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      maxLines: maxLines,
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildNumberField(String label, double initial, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initial.toString(),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        keyboardType: TextInputType.number,
        onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
        onSaved: (val) => onChanged(double.tryParse(val ?? '0') ?? 0),
      ),
    );
  }

  Widget _buildMonthPicker(String label, String initial, Function(String) onChanged) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(labelText: label, hintText: 'yyyy-MM', border: const OutlineInputBorder(), isDense: true),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Required';
        if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(val)) return 'Format: yyyy-MM';
        return null;
      },
      onChanged: onChanged,
      onSaved: (val) => onChanged(val ?? ''),
    );
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

          // Calculate Adjusted Totals from Performance Metrics
          final metrics = provider.getMonthlyPerformanceMetrics();
          double adjustedPmeTotal = 0;
          
          // Sum PME from all months
          for (var key in metrics.keys) {
            if (key != 'OTE_GLOBAL') {
              adjustedPmeTotal += metrics[key]!['pme_budget'] ?? 0;
            }
          }

          // Get OTE from global key
          double adjustedOteTotal = metrics['OTE_GLOBAL']?['ote_budget'] ?? 0;

          // Use raw period totals only if metrics are empty
          double totalPme = adjustedPmeTotal != 0 ? adjustedPmeTotal : provider.budgetPeriods
              .where((p) => p.isActive)
              .fold(0.0, (sum, p) => sum + p.totalPmeBudget);
          double totalOte = adjustedOteTotal != 0 ? adjustedOteTotal : provider.budgetPeriods
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
                        const Text('Adjusted PME Limit', style: TextStyle(color: Colors.white70)),
                        Text('₹${NumberFormat('#,##,###').format(totalPme)}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    Column(
                      children: [
                        const Text('Adjusted OTE Limit', style: TextStyle(color: Colors.white70)),
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
                        title: Row(
                          children: [
                            Expanded(child: Text(period.name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('PME: ₹${NumberFormat('#,##,###').format(period.totalPmeBudget)}', 
                              style: TextStyle(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(child: Text('${_formatMonth(period.startMonth)} → ${_formatMonth(period.endMonth)}', 
                              style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text('OTE: ₹${NumberFormat('#,##,###').format(period.oteAmount)}', 
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                          ],
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildSummaryRow('PME Monthly Average', period.defaultPmeAmount),
                                _buildSummaryRow('PME Total (Period)', period.totalPmeBudget, isBold: true),
                                _buildSummaryRow('OTE Budget', period.oteAmount, isBold: true),
                                const Divider(),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Monthly Adjustments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                ...period.getAllMonths().map((month) {
                                  // Show adjusted monthly limit if available
                                  final baseAmount = period.getPmeForMonth(month);
                                  final adjustedAmount = metrics[month]?['pme_budget'] ?? baseAmount;
                                  final hasOverride = period.monthlyPme.containsKey(month) || (adjustedAmount != baseAmount);
                                  
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(_formatMonth(month), style: const TextStyle(fontSize: 13)),
                                    subtitle: period.monthlyPmeRemarks.containsKey(month)
                                      ? Text(period.monthlyPmeRemarks[month]!, style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic))
                                      : (adjustedAmount != baseAmount ? const Text('Adjusted via Transfer', style: TextStyle(fontSize: 11, color: Colors.blue, fontStyle: FontStyle.italic)) : null),
                                    trailing: Text(
                                      '₹${NumberFormat('#,##,###').format(adjustedAmount)}',
                                      style: TextStyle(
                                        color: hasOverride ? Colors.orange : null,
                                        fontWeight: hasOverride ? FontWeight.bold : null,
                                      ),
                                    ),
                                    onTap: () => _editMonthAmountFromList(period, month, baseAmount),
                                  );
                                }).toList(),
                                if (period.remarks.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text('Remarks: ${period.remarks}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
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
