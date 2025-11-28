import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_equipment_screen.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:drone_academy/screens/equipment_history_screen.dart';

class ManageEquipmentScreen extends StatefulWidget {
  const ManageEquipmentScreen({super.key});

  @override
  State<ManageEquipmentScreen> createState() => _ManageEquipmentScreenState();
}

class _ManageEquipmentScreenState extends State<ManageEquipmentScreen>
    with AutomaticKeepAliveClientMixin {
  late AppLocalizations l10n;
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  Future<void> _showDeleteConfirmationDialog(DocumentSnapshot item) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.confirmDeletion),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('${l10n.areYouSureDelete} ${item['name']}?'),
                const Text('This action cannot be undone.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(l10n.delete),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('equipment')
                    .doc(item.id)
                    .delete();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment')
            .orderBy('type')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noEquipmentAddedYet,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          final equipmentList = snapshot.data!.docs;

          final Map<String, List<DocumentSnapshot>> equipmentByType = {};
          for (var equipment in equipmentList) {
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
                    final data = item.data() as Map<String, dynamic>;
                    final imageUrl = data.containsKey('imageUrl')
                        ? data['imageUrl']
                        : null;
                    final itemName = data['name'] ?? l10n.unknownEquipment;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            (imageUrl != null && imageUrl.isNotEmpty)
                            ? CachedNetworkImageProvider(imageUrl)
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: (imageUrl == null || imageUrl.isEmpty)
                            ? const Icon(Icons.precision_manufacturing_outlined)
                            : null,
                      ),
                      title: Text(
                        item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(_translateKey(item['type'])),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EquipmentHistoryScreen(
                              equipmentId: item.id,
                              equipmentName: itemName,
                            ),
                          ),
                        );
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status']),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _translateKey(item['status']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditEquipmentScreen(equipment: item),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _showDeleteConfirmationDialog(item),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-manage-equipment',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditEquipmentScreen(),
            ),
          );
        },
        tooltip: l10n.addEquipment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
