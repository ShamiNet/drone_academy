import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_equipment_screen.dart';
import 'package:drone_academy/screens/equipment_history_screen.dart';
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageEquipmentScreen extends StatefulWidget {
  const ManageEquipmentScreen({super.key});

  @override
  State<ManageEquipmentScreen> createState() => _ManageEquipmentScreenState();
}

class _ManageEquipmentScreenState extends State<ManageEquipmentScreen> {
  final ApiService _apiService = ApiService(); // استخدام الخدمة
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF4CAF50);
      case 'inUse':
        return const Color(0xFFFF9800);
      case 'inMaintenance':
        return const Color(0xFFF44336);
      default:
        return Colors.grey;
    }
  }

  String _translateKey(String key) {
    switch (key) {
      case 'drone':
        return l10n.drone;
      case 'battery':
        return l10n.battery;
      case 'controller':
        return l10n.controller;
      case 'other':
        return l10n.other;
      case 'available':
        return l10n.available;
      case 'inUse':
        return l10n.inUse;
      case 'inMaintenance':
        return l10n.inMaintenance;
      default:
        return key;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'drone':
        return Icons.flight;
      case 'battery':
        return Icons.battery_std;
      case 'controller':
        return Icons.gamepad;
      default:
        return Icons.build;
    }
  }

  void _showDeleteConfirmationDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.confirmDeletion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '${l10n.areYouSureDelete} $name?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            onPressed: () {
              _apiService.deleteEquipment(id); // الحذف عبر السيرفر
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditEquipmentScreen()),
        ),
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      // استخدام streamEquipment من ApiService
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamEquipment(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final equipmentList = snapshot.data ?? [];
          if (equipmentList.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noEquipmentAddedYet,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          // تجميع البيانات (التي أصبحت Map الآن)
          final Map<String, List<dynamic>> equipmentByType = {};
          for (var equipment in equipmentList) {
            final type = equipment['type'] as String? ?? 'other';
            if (equipmentByType[type] == null) equipmentByType[type] = [];
            equipmentByType[type]!.add(equipment);
          }
          final sortedTypes = equipmentByType.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTypes.length,
            itemBuilder: (context, index) {
              final type = sortedTypes[index];
              final items = equipmentByType[type]!;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    collapsedIconColor: Colors.grey,
                    iconColor: const Color(0xFF8FA1B4),
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(
                            0xFF3F51B5,
                          ).withOpacity(0.2),
                          child: Icon(
                            _getIconForType(type),
                            color: const Color(0xFF5C6BC0),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_translateKey(type)} (${items.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    children: items.map((item) {
                      final imageUrl = item['imageUrl'];
                      final status = item['status'] ?? 'available';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _showDeleteConfirmationDialog(
                                item['id'],
                                item['name'],
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: 20,
                              ),
                              // ملاحظة: يجب تحديث EditEquipmentScreen ليقبل Map أيضاً
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditEquipmentScreen(equipment: item),
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _translateKey(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _translateKey(item['type'] ?? 'other'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EquipmentHistoryScreen(
                                    equipmentId: item['id'],
                                    equipmentName: item['name'] ?? '',
                                  ),
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage:
                                    (imageUrl != null && imageUrl.isNotEmpty)
                                    ? CachedNetworkImageProvider(imageUrl)
                                    : null,
                                child: (imageUrl == null || imageUrl.isEmpty)
                                    ? Icon(
                                        _getIconForType(item['type']),
                                        color: Colors.grey,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
