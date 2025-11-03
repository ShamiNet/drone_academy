import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
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
        return 'All'; // Needs localization
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

  Future<void> _checkOutItem(DocumentSnapshot item) async {
    final itemRef = FirebaseFirestore.instance
        .collection('equipment')
        .doc(item.id);
    final logRef = FirebaseFirestore.instance.collection('equipment_log').doc();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(itemRef, {
      'status': 'inUse',
      'currentUserId': currentUserId,
      'currentUserName': currentUserName,
    });

    batch.set(logRef, {
      'equipmentId': item.id,
      'equipmentName': item['name'],
      'userId': currentUserId,
      'userName': currentUserName,
      'checkOutTime': Timestamp.now(),
      'checkInTime': null,
      'notesOnReturn': '',
    });

    await batch.commit();
  }

  Future<void> _showCheckInDialog(DocumentSnapshot item) async {
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
                    onChanged: (value) {
                      setDialogState(() => needsMaintenance = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    _checkInItem(item, notesController.text, needsMaintenance);
                    Navigator.pop(context);
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
    DocumentSnapshot item,
    String notes,
    bool needsMaintenance,
  ) async {
    final itemRef = FirebaseFirestore.instance
        .collection('equipment')
        .doc(item.id);

    final logQuery = await FirebaseFirestore.instance
        .collection('equipment_log')
        .where('equipmentId', isEqualTo: item.id)
        .where('checkInTime', isEqualTo: null)
        .orderBy('checkOutTime', descending: true)
        .limit(1)
        .get();

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(itemRef, {
      'status': needsMaintenance ? 'inMaintenance' : 'available',
      'currentUserId': FieldValue.delete(),
      'currentUserName': FieldValue.delete(),
    });

    if (logQuery.docs.isNotEmpty) {
      final logDocRef = logQuery.docs.first.reference;
      batch.update(logDocRef, {
        'checkInTime': Timestamp.now(),
        'notesOnReturn': notes,
      });
    }

    await batch.commit();
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
                labelText: 'Filter by Status', // Needs localization
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text(_translateKey('all'))),
                DropdownMenuItem(
                    value: 'available',
                    child: Text(_translateKey('available'))),
                DropdownMenuItem(
                    value: 'inUse', child: Text(_translateKey('inUse'))),
                DropdownMenuItem(
                    value: 'inMaintenance',
                    child: Text(_translateKey('inMaintenance'))),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filterStatus = value;
                  });
                }
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map<String, String> usersMap = {
                  for (var doc in userSnapshot.data!.docs)
                    doc.id: doc['displayName']?.toString() ?? 'Unknown',
                };

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('equipment')
                      .orderBy('type')
                      .snapshots(),
                  builder: (context, equipmentSnapshot) {
                    if (equipmentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!equipmentSnapshot.hasData ||
                        equipmentSnapshot.data!.docs.isEmpty) {
                      return EmptyStateWidget(
                        message: l10n.noEquipmentAddedYet,
                        imagePath: 'assets/illustrations/no_data.svg',
                      );
                    }

                    final equipmentList = equipmentSnapshot.data!.docs;

                    final filteredList = _filterStatus == 'all'
                        ? equipmentList
                        : equipmentList
                            .where((doc) => doc['status'] == _filterStatus)
                            .toList();

                    if (filteredList.isEmpty) {
                      return const EmptyStateWidget(
                        message: "No equipment with this status.", // Needs localization
                        imagePath: 'assets/illustrations/no_data.svg',
                      );
                    }

                    final Map<String, List<DocumentSnapshot>> equipmentByType = {};
                    for (var equipment in filteredList) {
                      final type = equipment['type'] as String? ?? 'other';
                      if (equipmentByType[type] == null) {
                        equipmentByType[type] = [];
                      }
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
                              vertical: 8.0, horizontal: 8.0),
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
                              final data = item.data() as Map<String, dynamic>;
                              final imageUrl = data.containsKey('imageUrl')
                                  ? data['imageUrl']
                                  : null;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      (imageUrl != null && imageUrl.isNotEmpty)
                                          ? CachedNetworkImageProvider(imageUrl)
                                          : null,
                                  backgroundColor: Colors.grey.shade200,
                                  child: (imageUrl == null || imageUrl.isEmpty)
                                      ? const Icon(
                                          Icons
                                              .precision_manufacturing_outlined)
                                      : null,
                                ),
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(_translateKey(item['type'])),
                                trailing: _buildActionButton(item, usersMap),
                              );
                            }).toList(),
                          ),
                        );
                      },
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

  Widget _buildActionButton(
    DocumentSnapshot item,
    Map<String, String> usersMap,
  ) {
    final data = item.data() as Map<String, dynamic>;
    final status = data['status'];

    if (status == 'available') {
      return ElevatedButton(
        onPressed: () => _checkOutItem(item),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: Text(l10n.checkOut),
      );
    }

    if (status == 'inUse') {
      final currentBorrowerId = data.containsKey('currentUserId')
          ? data['currentUserId']
          : null;

      if (currentBorrowerId != null && currentBorrowerId == currentUserId) {
        return ElevatedButton(
          onPressed: () => _showCheckInDialog(item),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
          child: Text(l10n.checkIn),
        );
      } else {
        final currentBorrowerName =
            usersMap[currentBorrowerId] ?? data['currentUserName'] ?? '...';

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

    return Container(); // حالة افتراضية
  }
}
