// lib/screens/inventory_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InventoryHistoryScreen extends StatelessWidget {
  final String itemId;
  final String itemName;

  const InventoryHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(itemName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight / 2),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              l10n.inventoryHistory,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).appBarTheme.foregroundColor?.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // جلب كل السجلات الخاصة بهذا الصنف، مرتبة من الأحدث للأقدم
        stream: FirebaseFirestore.instance
            .collection('inventory_log')
            .where('itemId', isEqualTo: itemId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noHistoryFound,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          final logs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final data = log.data() as Map<String, dynamic>;

              final userName = data['userName'] ?? 'Unknown';
              final date = (data['date'] as Timestamp).toDate();
              final checkedOut = data['quantityCheckedOut'] ?? 0;
              final returned = data['quantityReturned'] ?? 0;
              final lost = data['quantityLost'] ?? 0;

              // تحديد نوع الحركة ولونها
              IconData icon;
              Color color;
              String title;

              if (checkedOut > 0) {
                title = '${l10n.checkOut}: $checkedOut';
                icon = Icons.arrow_upward;
                color = Colors.orange;
              } else if (returned > 0) {
                title = '${l10n.checkIn}: $returned';
                icon = Icons.arrow_downward;
                color = Colors.green;
              } else if (lost > 0) {
                title = '${l10n.quantityLost}: $lost';
                icon = Icons.warning_amber_rounded;
                color = Colors.red;
              } else {
                title = 'حركة غير معروفة';
                icon = Icons.help_outline;
                color = Colors.grey;
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  subtitle: Text(
                    '${l10n.users}: $userName\n${DateFormat.yMMMd().add_jm().format(date)}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
