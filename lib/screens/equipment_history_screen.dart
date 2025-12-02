import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EquipmentHistoryScreen extends StatefulWidget {
  final String equipmentId;
  final String equipmentName;

  const EquipmentHistoryScreen({
    super.key,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  State<EquipmentHistoryScreen> createState() => _EquipmentHistoryScreenState();
}

class _EquipmentHistoryScreenState extends State<EquipmentHistoryScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.equipmentName)),
      body: FutureBuilder<List<dynamic>>(
        future: _apiService.fetchEquipmentLogs(widget.equipmentId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const EmptyStateWidget(
              message: "No history yet.",
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          // ترتيب حسب التاريخ (الأحدث أولاً)
          logs.sort(
            (a, b) =>
                (b['checkOutTime'] ?? '').compareTo(a['checkOutTime'] ?? ''),
          );

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final userName = log['userName'] ?? 'Unknown';
              final checkOutTime = DateTime.parse(log['checkOutTime']);
              final checkInTime = log['checkInTime'] != null
                  ? DateTime.parse(log['checkInTime'])
                  : null;
              final notes = log['notesOnReturn'] ?? '';

              return Card(
                child: ListTile(
                  isThreeLine: true,
                  title: Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${l10n.checkedOut}: ${DateFormat.yMMMd().add_jm().format(checkOutTime)}",
                      ),
                      if (checkInTime != null)
                        Text(
                          "${l10n.checkedIn}: ${DateFormat.yMMMd().add_jm().format(checkInTime)}",
                          style: const TextStyle(color: Colors.green),
                        ),
                      if (notes.isNotEmpty) Text("Note: $notes"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await _apiService.deleteEquipmentLog(log['id']);
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
