import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EquipmentCheckoutScreen extends StatefulWidget {
  const EquipmentCheckoutScreen({super.key});

  @override
  State<EquipmentCheckoutScreen> createState() =>
      _EquipmentCheckoutScreenState();
}

class _EquipmentCheckoutScreenState extends State<EquipmentCheckoutScreen> {
  final ApiService _apiService = ApiService(); // الخدمة
  late AppLocalizations l10n;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String currentUserName =
      FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown';
  String _filterStatus = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  // ... (دوال الألوان والترجمة نفسها - يمكنك نسخها من الملف القديم أو تركها هنا)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'inUse':
        return Colors.amber;
      case 'inMaintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _translateKey(String key) {
    // ... (نفس منطق الترجمة السابق) ...
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
      case 'all':
        return l10n.all;
      default:
        return key;
    }
  }

  Icon _getIconForType(String type) {
    switch (type) {
      case 'drone':
        return const Icon(Icons.flight);
      case 'battery':
        return const Icon(Icons.battery_full);
      case 'controller':
        return const Icon(Icons.gamepad);
      default:
        return const Icon(Icons.build);
    }
  }

  // --- دالة الاستعارة (محدثة) ---
  Future<void> _checkOutItem(Map<String, dynamic> item) async {
    // تحديث الحالة في المعدات
    await _apiService.updateEquipment(item['id'], {
      'status': 'inUse',
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
    });

    // إضافة سجل في Log
    await _apiService.addEquipmentLog({
      'equipmentId': item['id'],
      'equipmentName': item['name'],
      'userId': currentUserId,
      'userName': currentUserName,
      'checkOutTime': DateTime.now().toIso8601String(), // وقت الاستعارة
      'checkInTime': null,
      'notesOnReturn': '',
    });
  }

  // --- دالة الإرجاع (محدثة) ---
  Future<void> _showCheckInDialog(Map<String, dynamic> item) async {
    final notesController = TextEditingController();
    bool needsMaintenance = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.checkInItem),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: l10n.notesOnReturn,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.reportMaintenance),
                    value: needsMaintenance,
                    onChanged: (value) =>
                        setDialogState(() => needsMaintenance = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // منطق الإرجاع الجديد
                    await _checkInItem(
                      item,
                      notesController.text,
                      needsMaintenance,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(l10n.checkIn),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkInItem(
    Map<String, dynamic> item,
    String notes,
    bool needsMaintenance,
  ) async {
    // 1. تحديث حالة المعدة
    await _apiService.updateEquipment(item['id'], {
      'status': needsMaintenance ? 'inMaintenance' : 'available',
      'currentUserId': '', // تفريغ المستخدم
      'currentUserName': '',
    });

    // 2. تحديث السجل (إغلاق جلسة الاستعارة)
    // نحتاج للبحث عن السجل المفتوح.
    // للتبسيط هنا: سنضيف سجل جديد للإرجاع أو نحدث الأخير.
    // الأفضل في تصميم الـ API أن يكون هناك endpoint خاص بـ "return" يغلق آخر سجل.
    // سنفترض هنا إضافة سجل جديد للإرجاع لتوثيق العملية
    await _apiService.addEquipmentLog({
      'equipmentId': item['id'],
      'equipmentName': item['name'],
      'userId': currentUserId,
      'userName': currentUserName,
      'checkOutTime': null, // لا يوجد وقت استعارة جديد
      'checkInTime': DateTime.now().toIso8601String(), // وقت الإرجاع
      'notesOnReturn': notes,
      'type': 'return', // علامة لتمييز الإرجاع
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(_translateKey('all')),
                ),
                DropdownMenuItem(
                  value: 'available',
                  child: Text(_translateKey('available')),
                ),
                DropdownMenuItem(
                  value: 'inUse',
                  child: Text(_translateKey('inUse')),
                ),
                DropdownMenuItem(
                  value: 'inMaintenance',
                  child: Text(_translateKey('inMaintenance')),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _filterStatus = value);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              // استخدام streamEquipment من السيرفر
              stream: _apiService.streamEquipment(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final equipmentList = snapshot.data ?? [];

                if (equipmentList.isEmpty) {
                  return EmptyStateWidget(
                    message: l10n.noEquipmentAddedYet,
                    imagePath: 'assets/illustrations/no_data.svg',
                  );
                }

                final filteredList = _filterStatus == 'all'
                    ? equipmentList
                    : equipmentList
                          .where((doc) => doc['status'] == _filterStatus)
                          .toList();

                if (filteredList.isEmpty) {
                  return const EmptyStateWidget(
                    message: "No equipment with this status.",
                    imagePath: 'assets/illustrations/no_data.svg',
                  );
                }

                final Map<String, List<dynamic>> equipmentByType = {};
                for (var equipment in filteredList) {
                  final type = equipment['type'] as String? ?? 'other';
                  if (equipmentByType[type] == null) equipmentByType[type] = [];
                  equipmentByType[type]!.add(equipment);
                }

                final sortedTypes = equipmentByType.keys.toList()..sort();

                return ListView.builder(
                  itemCount: sortedTypes.length,
                  itemBuilder: (context, index) {
                    final type = sortedTypes[index];
                    final items = equipmentByType[type]!;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 8.0,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: Text(
                          '${_translateKey(type)} (${items.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        leading: CircleAvatar(child: _getIconForType(type)),
                        initiallyExpanded: true,
                        children: items.map((item) {
                          final imageUrl = item['imageUrl'];
                          final itemName =
                              item['name'] ?? l10n.unknownEquipment;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  (imageUrl != null &&
                                      imageUrl.toString().isNotEmpty)
                                  ? CachedNetworkImageProvider(imageUrl)
                                  : null,
                              backgroundColor: Colors.grey.shade200,
                              child:
                                  (imageUrl == null ||
                                      imageUrl.toString().isEmpty)
                                  ? const Icon(
                                      Icons.precision_manufacturing_outlined,
                                    )
                                  : null,
                            ),
                            title: Text(
                              itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_translateKey(item['type'])),
                            trailing: _buildActionButton(item),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> item) {
    final status = item['status'];

    if (status == 'available') {
      return ElevatedButton(
        onPressed: () => _checkOutItem(item),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: Text(l10n.checkOut),
      );
    }

    if (status == 'inUse') {
      final currentBorrowerId = item['currentUserId'];

      if (currentBorrowerId != null && currentBorrowerId == currentUserId) {
        return ElevatedButton(
          onPressed: () => _showCheckInDialog(item),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          child: Text(l10n.checkIn),
        );
      } else {
        final currentBorrowerName = item['currentUserName'] ?? '...';
        return Tooltip(
          message: currentBorrowerName,
          child: Text(
            '${l10n.checkedOutBy}\n$currentBorrowerName',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }
    }

    if (status == 'inMaintenance') {
      return Text(
        _translateKey(status),
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Container();
  }
}
