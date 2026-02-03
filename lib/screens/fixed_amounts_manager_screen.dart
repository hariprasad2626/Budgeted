import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';
import '../models/fixed_amount.dart';
import '../services/firestore_service.dart';

class FixedAmountsManagerScreen extends StatelessWidget {
  const FixedAmountsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fixed Personal Balances')),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          final items = provider.fixedAmounts;
          
          if (items.isEmpty) {
            return const Center(child: Text('No fixed amounts saved yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(item.remarks, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Add-on to Personal Balance'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${item.amount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.tealAccent)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showAddDialog(context, template: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, item.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, {FixedAmount? template}) {
    final remarksController = TextEditingController(text: template?.remarks ?? '');
    final amountController = TextEditingController(text: template?.amount.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template == null ? 'Add Fixed Amount' : 'Edit Fixed Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(labelText: 'Purpose / Remarks (e.g. Bank Savings)'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final remarks = remarksController.text.trim();
              final amountStr = amountController.text.trim();
              final amount = double.tryParse(amountStr) ?? 0;
              
              if (remarks.isEmpty || amount <= 0) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Please enter valid remarks and amount'))
                 );
                 return;
              }

              try {
                final service = FirestoreService();
                if (template == null) {
                  await service.addFixedAmount(FixedAmount(
                    id: '',
                    remarks: remarks,
                    amount: amount,
                    createdAt: DateTime.now(),
                  ));
                } else {
                  await service.updateFixedAmount(FixedAmount(
                    id: template.id,
                    remarks: remarks,
                    amount: amount,
                    createdAt: template.createdAt,
                  ));
                }
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving: $e'))
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

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to remove this fixed balance component?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteFixedAmount(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
