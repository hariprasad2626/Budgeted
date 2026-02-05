import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';

class MonthlyBudgetReportScreen extends StatelessWidget {
  const MonthlyBudgetReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budget vs Actual'),
        backgroundColor: Colors.teal.shade800,
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final metrics = provider.getMonthlyPerformanceMetrics();
          final months = metrics.keys.toList()..sort((a, b) => b.compareTo(a)); // Descending

          if (months.isEmpty) {
            return const Center(child: Text('No budget data found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final data = metrics[month]!;
              final pmeBudget = data['pme_budget']!;
              final pmeActual = data['pme_actual']!;
              final oteActual = data['ote_actual']!;
              
              // Formatting
              final date = _parseMonth(month);
              final monthName = DateFormat('MMMM yyyy').format(date);
              
              // Calculations
              final pmeBalance = pmeBudget - pmeActual;
              final pmeProgress = pmeBudget > 0 ? (pmeActual / pmeBudget).clamp(0.0, 1.0) : 0.0;
              final isPmeOver = pmeActual > pmeBudget;

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const Divider(height: 24),
                      
                      // PME Section
                      Row(
                        children: [
                          const Icon(Icons.repeat, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          const Text('PME (Recurring)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            'Left: ₹${pmeBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: pmeBalance < 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Budget: ₹${pmeBudget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey)),
                          Text('Spent: ₹${pmeActual.toStringAsFixed(0)}', style: const TextStyle(color: Colors.blueGrey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pmeProgress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(isPmeOver ? Colors.red : Colors.teal),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // OTE Section (Just Actuals for now as OTE is period-based, not strictly monthly allocated)
                      Row(
                        children: [
                          const Icon(Icons.flash_on, size: 16, color: Colors.orangeAccent),
                          const SizedBox(width: 8),
                          const Text('OTE (One-Time)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            'Spent: ₹${oteActual.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  DateTime _parseMonth(String yyyyMM) {
    try {
      return DateFormat('yyyy-MM').parse(yyyyMM);
    } catch (_) {
      return DateTime.now();
    }
  }
}
