import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InventoryHistoryScreen extends StatefulWidget {
  final String itemId;
  final String itemName;

  const InventoryHistoryScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.itemName),
        backgroundColor: bgColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight / 2),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              l10n.inventoryHistory,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        // جلب السجل من السيرفر
        future: _apiService.fetchInventoryLogs(widget.itemId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error fetching logs: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noHistoryFound,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final userName = log['userName'] ?? 'Unknown';

              DateTime date;
              if (log['date'] != null) {
                date = DateTime.parse(log['date']);
              } else {
                date = DateTime.now();
              }

              final checkedOut = log['quantityCheckedOut'] ?? 0;
              final returned = log['quantityReturned'] ?? 0;
              final lost = log['quantityLost'] ?? 0;

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
                title = 'Unknown Action';
                icon = Icons.help_outline;
                color = Colors.grey;
              }

              return Card(
                color: const Color(0xFF1E2230),
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
                    style: const TextStyle(color: Colors.grey),
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
