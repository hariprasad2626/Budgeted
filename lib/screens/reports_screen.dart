import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/accounting_provider.dart';
import '../models/expense.dart';
import '../models/budget_category.dart';
import '../models/donation.dart';
import 'add_expense_screen.dart';
import 'transaction_history_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & Reports')),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final activeCenter = provider.activeCostCenter;
          if (activeCenter == null) {
            return const Center(child: Text('Please select a Cost Center first.'));
          }

          final categories = provider.categories;
          final expenses = provider.expenses;
          final donations = provider.donations;

          // --- Data Preparation ---

          // 1. Group by Main Category for Bar Chart
          final Map<String, _CategoryStats> mainCategoryStats = {};
          for (var cat in categories) {
            final status = provider.getCategoryStatus(cat);
            if (!mainCategoryStats.containsKey(cat.category)) {
              mainCategoryStats[cat.category] = _CategoryStats();
            }
            mainCategoryStats[cat.category]!.limit += status['total_limit']!;
            mainCategoryStats[cat.category]!.spent += status['spent']!;
          }

          // 2. Expense Pie Data
          final Map<String, double> expenseByCategory = {};
          for (var e in expenses) {
             // Find category name
             String catName = 'Uncategorized';
             try {
               final cat = categories.firstWhere((c) => c.id == e.categoryId);
               catName = cat.category;
             } catch (_) {}
             expenseByCategory[catName] = (expenseByCategory[catName] ?? 0) + e.amount;
          }

          // 3. Totals
          double totalBudgetRaw = mainCategoryStats.values.fold(0, (sum, s) => sum + s.limit);
          double totalSpent = mainCategoryStats.values.fold(0, (sum, s) => sum + s.spent);
          double totalDonations = donations.fold(0, (sum, d) => sum + d.amount);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(totalBudgetRaw, totalSpent, totalDonations),
                const SizedBox(height: 24),
                
                const Text('Budget vs Spent (By Category)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildBarChart(mainCategoryStats, (cat) => _showDetails(context, provider, cat)),
                
                const SizedBox(height: 32),
                
                const Text('Expense Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPieChart(expenseByCategory, (cat) => _showDetails(context, provider, cat)),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(double budget, double spent, double donations) {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'Total Limit', value: budget, color: Colors.blueAccent, icon: Icons.account_balance_wallet)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(title: 'Total Spent', value: spent, color: Colors.orangeAccent, icon: Icons.shopping_cart)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(title: 'Donations', value: donations, color: Colors.greenAccent, icon: Icons.volunteer_activism)),
      ],
    );
  }

  void _showDetails(BuildContext context, AccountingProvider provider, String mainCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryScreen(
          title: '$mainCategory Expenses',
          type: 'Expense',
          addScreen: const AddExpenseScreen(), // Not ideal to have "add" here, but fits the signature
          itemSelector: (p) {
            final categoryIds = p.categories
                .where((c) => c.category == mainCategory)
                .map((c) => c.id)
                .toSet();
            return p.expenses
                .where((e) => categoryIds.contains(e.categoryId))
                .toList();
          },
          showEntryDetails: (context, item, type) {
            // Re-using the simpler viewer for now, can be improved later
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('$type Details'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remarks: ${item.remarks ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Amount: ₹${item.amount}'),
                    Text('Date: ${DateFormat('yyyy-MM-dd').format(item.date)}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (c) => AddExpenseScreen(expenseToEdit: item as Expense)));
                    },
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, item);
                    },
                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Expense item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteExpense(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(Map<String, _CategoryStats> stats, Function(String) onTap) {
    if (stats.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No category data')));

    final List<BarChartGroupData> barGroups = [];
    int index = 0;
    final keys = stats.keys.toList()..sort();

    for (var key in keys) {
      final stat = stats[key]!;
      double l = stat.limit > 0 ? stat.limit : 0;
      double s = stat.spent > 0 ? stat.spent : 0;
      
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(toY: l, color: Colors.blueAccent.withOpacity(0.5), width: 12, borderRadius: BorderRadius.circular(2)),
            BarChartRodData(toY: s, color: Colors.orangeAccent, width: 12, borderRadius: BorderRadius.circular(2)),
          ],
        ),
      );
      index++;
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            touchCallback: (FlTouchEvent event, barTouchResponse) {
              if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                return;
              }
              if (event is FlTapUpEvent) {
                final idx = barTouchResponse.spot!.touchedBarGroupIndex;
                if (idx >= 0 && idx < keys.length) {
                  onTap(keys[idx]);
                }
              }
            },
          ),
          barGroups: barGroups,
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  if (val.toInt() >= 0 && val.toInt() < keys.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(keys[val.toInt()].substring(0, keys[val.toInt()].length > 4 ? 4 : keys[val.toInt()].length), style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> data, Function(String) onTap) {
    if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No expense data')));

    final List<PieChartSectionData> sections = [];
    final List<Color> colors = [Colors.blue, Colors.red, Colors.green, Colors.yellow, Colors.purple, Colors.orange];
    int i = 0;
    
    // Sort keys to ensure consistent index mapping for touch events
    final keys = data.keys.toList()..sort();
    
    double total = data.values.fold(0, (p, c) => p + c);
    
    for (var key in keys) {
      double val = data[key] ?? 0;
      if (val > 0) {
        sections.add(
            PieChartSectionData(
            value: val,
            title: total > 0 ? '${(val / total * 100).toStringAsFixed(0)}%' : '',
            color: colors[i % colors.length],
            radius: 60,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
        );
      } else {
        // Add dummy section with 0 value if needed, but fl_chart might ignore 0.
        // If we skip 0 values, we need to make sure the keys list matches the rendered sections for indexing.
        // Wait, if I skip 0 values in the loop, 'keys' list will have more items than 'sections'.
        // I must filter 'keys' first.
      }
      i++;
    }
    
    // Re-filter keys to match sections exactly
    final activeKeys = keys.where((k) => (data[k] ?? 0) > 0).toList();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                      return;
                    }
                    if (event is FlTapUpEvent) {
                      final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      if (idx >= 0 && idx < activeKeys.length) {
                        onTap(activeKeys[idx]);
                      }
                    }
                  },
                ),
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
        ),
        Expanded(
           flex: 1,
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             crossAxisAlignment: CrossAxisAlignment.start,
             children: activeKeys.map((key) {
               final color = colors[keys.indexOf(key) % colors.length]; // Use original keys index for stable color mapping if possible? Or just re-calc colors.
               // Actually in the loop above: `colors[i % colors.length]`. `i` incremented for every key!
               // Wait, `i` increments for every key in the first loop.
               // To keep colors consistent between Chart and Legend, I need to use the exact same logic.
               
               // Logic used in chart loop:
               // iterate sorted `keys`. 
               // i starts at 0. increments for every key.
               // IF val > 0, add section with `colors[i]`.
               // So if key 2 checks out, it gets `colors[2]`.
               
               // Legend loop:
               // Iterate activeKeys. 
               // Need to find the original index `i` for that key to get the right color.
               
               int originalIndex = keys.indexOf(key);
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4),
                 child: Row(
                   children: [
                     Container(width: 12, height: 12, color: colors[originalIndex % colors.length]),
                     const SizedBox(width: 8),
                     Expanded(child: Text(key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                   ],
                 ),
               );
             }).toList(),
           ),
        ),
      ],
    );
  }
}

class _CategoryStats {
  double limit = 0;
  double spent = 0;
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          const SizedBox(height: 4),
          Text('₹${value.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
