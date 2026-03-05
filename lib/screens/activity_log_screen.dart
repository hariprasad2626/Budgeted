import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/activity_log.dart';
import '../providers/accounting_provider.dart';
import '../services/firestore_service.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History (Undo)'),
        backgroundColor: Colors.indigo.shade900,
      ),
      body: Consumer<AccountingProvider>(
        builder: (context, provider, child) {
          return StreamBuilder<List<ActivityLog>>(
            stream: FirestoreService().getActivityLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No activity logs found.'));
              }

              final logs = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _ActivityLogCard(log: log);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ActivityLogCard extends StatelessWidget {
  final ActivityLog log;

  const _ActivityLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _getActivityColor(log.activityType);
    final icon = _getActivityIcon(log.activityType);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(log.remarks, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '${DateFormat('MMM dd, HH:mm').format(log.timestamp)} • ${log.entityType.name}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.oldData != null) ...[
                  const Text('Previous State:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  _buildDataView(log.oldData!),
                  const SizedBox(height: 12),
                ],
                if (log.newData != null) ...[
                  const Text('New State:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  _buildDataView(log.newData!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmRollback(context, log),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo this change'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataView(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        data.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    );
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.CREATE: return Colors.greenAccent;
      case ActivityType.UPDATE: return Colors.blueAccent;
      case ActivityType.DELETE: return Colors.redAccent;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.CREATE: return Icons.add_circle;
      case ActivityType.UPDATE: return Icons.edit;
      case ActivityType.DELETE: return Icons.delete_forever;
    }
  }

  void _confirmRollback(BuildContext context, ActivityLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Undo'),
        content: Text('This will attempt to revert the action: "${log.remarks}". Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
               Navigator.pop(ctx);
               await _performRollback(context, log);
            },
            child: const Text('Yes, Undo'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRollback(BuildContext context, ActivityLog log) async {
    final service = FirestoreService();
    try {
      String collection = _getCollection(log.entityType);
      
      switch (log.activityType) {
        case ActivityType.CREATE:
          // Rollback Creation = Delete the item
          await service.deleteDocument(collection, log.entityId);
          break;
        case ActivityType.UPDATE:
          // Rollback Update = Restore oldData
          if (log.oldData != null) {
            await service.setDocument(collection, log.entityId, log.oldData!);
          }
          break;
        case ActivityType.DELETE:
          // Rollback Deletion = Re-create with oldData
          if (log.oldData != null) {
            await service.setDocument(collection, log.entityId, log.oldData!);
          }
          break;
      }

      // Delete the log entry after successful undo (optional, or just mark it?)
      // We'll keep it for now but maybe mark it. 
      // For simplicity, let's just delete the log so it doesn't show up as undoable anymore.
      await service.deleteActivityLog(log.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action successfully undone!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during undo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getCollection(EntityType type) {
    switch (type) {
      case EntityType.EXPENSE: return 'expenses';
      case EntityType.DONATION: return 'donations';
      case EntityType.TRANSFER: return 'fund_transfers';
      case EntityType.ADJUSTMENT: 
        // This is tricky as adjustments come in two collections.
        // We might need to store the collection name in the log too.
        // For now, let's guess based on the log remarks or store it.
        // Actually, let's update the model to include collection name if possible.
        return 'personal_adjustments'; 
      case EntityType.CATEGORY: return 'budget_categories';
      case EntityType.ALLOCATION: return 'budget_allocations';
      case EntityType.FIXED_AMOUNT: return 'fixed_amounts';
      case EntityType.BUDGET_PERIOD: return 'budget_periods';
    }
  }
}
