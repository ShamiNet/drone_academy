// lib/screens/inventory_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late AppLocalizations l10n;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String currentUserName =
      FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  // --- دالة إظهار نافذة "سحب" الكمية ---
  Future<void> _showCheckoutDialog(DocumentSnapshot item) async {
    final quantityController = TextEditingController();
    final data = item.data() as Map<String, dynamic>;
    final int availableQuantity = data['availableQuantity'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${'سحب صنف'}: ${data['name']}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.quantityToCheckout,
            hintText: '${l10n.availableQuantity}: $availableQuantity',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final int quantity = int.tryParse(quantityController.text) ?? 0;
              // التحقق من الكمية المدخلة
              if (quantity <= 0) {
                showCustomSnackBar(
                  context,
                  l10n.negativeQuantityError,
                ); // "الكميات لا يمكن أن تكون سالبة"
                return;
              }
              if (quantity > availableQuantity) {
                showCustomSnackBar(
                  context,
                  '${l10n.notEnoughStock} $availableQuantity',
                );
                return;
              }

              _updateInventory(item, quantity, 0);
              Navigator.pop(context);
              showCustomSnackBar(context, l10n.checkoutSuccess, isError: false);
            },
            child: Text(l10n.checkOut),
          ),
        ],
      ),
    );
  }

  // --- دالة إظهار نافذة "إرجاع" الكمية (مع التعديلات) ---
  Future<void> _showCheckInDialog(DocumentSnapshot item) async {
    final returnController = TextEditingController();
    final lostController = TextEditingController(text: '0');
    final data = item.data() as Map<String, dynamic>;
    final int availableQuantity = data['availableQuantity'];
    final int totalQuantity = data['totalQuantity'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${l10n.checkInItem}: ${item['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: returnController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.quantityToReturn),
            ),
            TextField(
              controller: lostController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.quantityLost),
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
              final int returnQty = int.tryParse(returnController.text) ?? 0;
              final int lostQty = int.tryParse(lostController.text) ?? 0;

              // --- بداية إصلاح منطق التحقق ---
              if (returnQty < 0 || lostQty < 0) {
                showCustomSnackBar(context, l10n.negativeQuantityError);
                return;
              }

              final int checkedOutQuantity = totalQuantity - availableQuantity;
              if (lostQty > checkedOutQuantity) {
                showCustomSnackBar(
                  context,
                  '${l10n.quantityLost} ($lostQty) ${l10n.cannotBeGreaterThan} الكمية المسحوبة ($checkedOutQuantity)',
                );
                return;
              }

              final int newAvailable = availableQuantity + returnQty;
              final int newTotal = totalQuantity - lostQty;

              if (newAvailable > newTotal) {
                showCustomSnackBar(
                  context,
                  '${l10n.quantityError}: ${l10n.availableQuantity} ($newAvailable) ${l10n.cannotBeGreaterThan} ${l10n.totalQuantity} ($newTotal)',
                );
                return;
              }
              // --- نهاية إصلاح منطق التحقق ---

              _updateInventory(item, -returnQty, lostQty);
              Navigator.pop(context);
              showCustomSnackBar(context, l10n.returnSuccess, isError: false);
            },
            child: Text(l10n.checkIn),
          ),
        ],
      ),
    );
  }

  // --- دالة تحديث المخزون (سحب وإرجاع) ---
  Future<void> _updateInventory(
    DocumentSnapshot item,
    int checkoutQty,
    int lostQty,
  ) async {
    final itemRef = FirebaseFirestore.instance
        .collection('inventory')
        .doc(item.id);
    final logRef = FirebaseFirestore.instance.collection('inventory_log').doc();
    final data = item.data() as Map<String, dynamic>;

    // checkoutQty: موجب عند السحب، وسالب عند الإرجاع
    final int newAvailable = data['availableQuantity'] - checkoutQty - lostQty;
    final int newTotal = data['totalQuantity'] - lostQty;

    WriteBatch batch = FirebaseFirestore.instance.batch();

    batch.update(itemRef, {
      'availableQuantity': newAvailable,
      'totalQuantity': newTotal,
    });

    batch.set(logRef, {
      'itemId': item.id,
      'itemName': item['name'],
      'userId': currentUserId,
      'userName': currentUserName,
      'date': Timestamp.now(),
      'quantityCheckedOut': checkoutQty > 0 ? checkoutQty : 0,
      'quantityReturned': checkoutQty < 0 ? -checkoutQty : 0,
      'quantityLost': lostQty,
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              final available = data['availableQuantity'];
              final total = data['totalQuantity'];
              final double percent = (total > 0) ? (available / total) : 0.0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          item['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${l10n.available}: $available / $total',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showCheckoutDialog(item),
                              child: Text(l10n.checkOut),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showCheckInDialog(item),
                              child: Text(l10n.checkIn),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percent > 0.5
                                ? Colors.green
                                : (percent > 0.2 ? Colors.amber : Colors.red),
                          ),
                        ),
                      ),
                    ],
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
