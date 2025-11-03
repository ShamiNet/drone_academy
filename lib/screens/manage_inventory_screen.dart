// lib/screens/manage_inventory_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/inventory_screen.dart';
import 'package:drone_academy/screens/edit_inventory_item_screen.dart';
import 'package:drone_academy/screens/inventory_history_screen.dart'; // 1. استيراد شاشة السجل
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  late AppLocalizations l10n;

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
                    .collection('inventory')
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

  // ... (دالة _translateKey لم تتغير)
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
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: TabBar(
          tabs: [
            Tab(text: l10n.operations, icon: const Icon(Icons.sync_alt)),
            Tab(text: l10n.inventoryList, icon: const Icon(Icons.list_alt)),
          ],
        ),
        body: TabBarView(
          children: [
            const InventoryScreen(), // شاشة السحب والإرجاع
            Scaffold(
              body: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('inventory')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return EmptyStateWidget(
                      message: l10n.noInventoryItems,
                      imagePath: 'assets/illustrations/no_data.svg',
                    );
                  }

                  final items = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final data = item.data() as Map<String, dynamic>;
                      final itemName = data['name'];
                      final available = data['availableQuantity'];
                      final total = data['totalQuantity'];

                      return Card(
                        child: ListTile(
                          title: Text(
                            itemName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${l10n.availableQuantity}: $available / $total',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InventoryHistoryScreen(
                                  itemId: item.id,
                                  itemName: itemName,
                                ),
                              ),
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EditInventoryItemScreen(item: item),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _showDeleteConfirmationDialog(item),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditInventoryItemScreen(),
                    ),
                  );
                },
                tooltip: l10n.addInventoryItem,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
