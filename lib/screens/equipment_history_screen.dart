// lib/screens/equipment_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EquipmentHistoryScreen extends StatelessWidget {
  final String equipmentId;
  final String equipmentName;

  const EquipmentHistoryScreen({
    super.key,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(equipmentName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight / 2),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              l10n.equipmentHistory,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).appBarTheme.foregroundColor?.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('users').get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnapshot.hasError) {
            return Center(
              child: Text('خطأ في جلب المستخدمين: ${userSnapshot.error}'),
            );
          }
          if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمين لعرض السجل.'));
          }

          final Map<String, String> usersMap = {
            for (var doc in userSnapshot.data!.docs)
              doc.id: doc['displayName']?.toString() ?? 'Unknown',
          };

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('equipment_log')
                .where('equipmentId', isEqualTo: equipmentId)
                .orderBy('checkOutTime', descending: true)
                .snapshots(),
            builder: (context, logSnapshot) {
              if (logSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (logSnapshot.hasError) {
                return Center(
                  child: Text('خطأ في جلب السجل: ${logSnapshot.error}'),
                );
              }
              if (!logSnapshot.hasData || logSnapshot.data!.docs.isEmpty) {
                return EmptyStateWidget(
                  message:
                      "لا يوجد سجل تاريخي لهذه القطعة بعد.",
                  imagePath: 'assets/illustrations/no_data.svg',
                );
              }

              final logs = logSnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final data = log.data() as Map<String, dynamic>;
                  final userId = data['userId']?.toString() ?? '';
                  final userName = usersMap[userId] ?? 'مستخدم غير معروف';
                  final checkOutTime = (data['checkOutTime'] as Timestamp).toDate();
                  final checkInTime = data['checkInTime'] != null
                      ? (data['checkInTime'] as Timestamp).toDate()
                      : null;
                  final notes = data['notesOnReturn'] ?? '';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${l10n.checkedOut}: ${DateFormat.yMMMd().add_jm().format(checkOutTime)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (checkInTime != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${l10n.checkedIn}: ${DateFormat.yMMMd().add_jm().format(checkInTime)}',
                                ),
                              ],
                            ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              '${l10n.notes}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(notes),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmationDialog(context, log, l10n),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showDeleteConfirmationDialog(BuildContext context, DocumentSnapshot log, AppLocalizations l10n) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text('${l10n.areYouSureDelete} this log entry?'),
        actions: <Widget>[
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          TextButton(
            child: Text(l10n.delete),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance.collection('equipment_log').doc(log.id).delete();
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Log entry deleted')),
              );
            },
          ),
        ],
      );
    },
  );
}
