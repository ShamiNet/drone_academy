import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_inventory_item_screen.dart';
import 'package:drone_academy/screens/inventory_history_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  final ApiService _apiService = ApiService();
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String currentUserName =
      FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown';

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          toolbarHeight: 0,
          bottom: TabBar(
            indicatorColor: const Color(0xFF8FA1B4),
            labelColor: const Color(0xFF8FA1B4),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: l10n.inventoryList, icon: const Icon(Icons.list_alt)),
              Tab(text: l10n.operations, icon: const Icon(Icons.sync_alt)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildInventoryListTab(), _buildOperationsTab()],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditInventoryItemScreen()),
          ),
          backgroundColor: const Color(0xFFFF9800),
          child: const Icon(Icons.add, color: Colors.black),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      ),
    );
  }

  Widget _buildInventoryListTab() {
    return StreamBuilder<List<dynamic>>(
      stream: _apiService.streamInventory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2230),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  item['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
                subtitle: Text(
                  '${item['availableQuantity']} / ${item['totalQuantity']} :الكمية المتاحة',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                // --- تفعيل الانتقال للسجل ---
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryHistoryScreen(
                      itemId: item['id'],
                      itemName: item['name'],
                    ),
                  ),
                ),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _showDeleteDialog(item['id'], item['name']),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      // --- تفعيل الانتقال للتعديل ---
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditInventoryItemScreen(item: item),
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
    );
  }

  Widget _buildOperationsTab() {
    return StreamBuilder<List<dynamic>>(
      stream: _apiService.streamInventory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final int available = item['availableQuantity'] ?? 0;
            final int total = item['totalQuantity'] ?? 1;
            final double percent = (total > 0) ? (available / total) : 0.0;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2230),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2C3246)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildOperationButton(
                            l10n.checkIn,
                            () => _showCheckInDialog(item),
                            isPrimary: false,
                          ),
                          const SizedBox(width: 8),
                          _buildOperationButton(
                            l10n.checkOut,
                            () => _showCheckoutDialog(item),
                            isPrimary: true,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'متاح: $available / $total',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      message: l10n.noInventoryItems,
      imagePath: 'assets/illustrations/no_data.svg',
    );
  }

  Widget _buildOperationButton(
    String label,
    VoidCallback onPressed, {
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFF8FA1B4)
            : Colors.transparent,
        foregroundColor: isPrimary ? Colors.black : const Color(0xFF8FA1B4),
        side: isPrimary ? null : const BorderSide(color: Color(0xFF8FA1B4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(0, 36),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Future<void> _showCheckoutDialog(Map<String, dynamic> item) async {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          'استعارة: ${item['name']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.quantityToCheckout,
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty > 0 && qty <= (item['availableQuantity'] ?? 0)) {
                _updateInventory(item, qty, 0);
                Navigator.pop(ctx);
                showCustomSnackBar(
                  context,
                  l10n.checkoutSuccess,
                  isError: false,
                );
              } else {
                showCustomSnackBar(context, 'الكمية غير صالحة');
              }
            },
            child: Text(l10n.checkOut),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckInDialog(Map<String, dynamic> item) async {
    final returnController = TextEditingController();
    final lostController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          'إرجاع: ${item['name']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: returnController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.quantityToReturn,
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
            TextField(
              controller: lostController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.quantityLost,
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              int ret = int.tryParse(returnController.text) ?? 0;
              int lost = int.tryParse(lostController.text) ?? 0;
              _updateInventory(item, -ret, lost);
              Navigator.pop(ctx);
              showCustomSnackBar(context, l10n.returnSuccess, isError: false);
            },
            child: Text(l10n.checkIn),
          ),
        ],
      ),
    );
  }

  Future<void> _updateInventory(
    Map<String, dynamic> item,
    int checkoutQty,
    int lostQty,
  ) async {
    final int newAvailable =
        (item['availableQuantity'] ?? 0) - checkoutQty - lostQty;
    final int newTotal = (item['totalQuantity'] ?? 0) - lostQty;

    await _apiService.updateInventoryItem(item['id'], {
      'availableQuantity': newAvailable,
      'totalQuantity': newTotal,
    });

    await _apiService.addInventoryLog({
      'itemId': item['id'],
      'itemName': item['name'],
      'userId': currentUserId,
      'userName': currentUserName,
      'date': DateTime.now(),
      'quantityCheckedOut': checkoutQty > 0 ? checkoutQty : 0,
      'quantityReturned': checkoutQty < 0 ? -checkoutQty : 0,
      'quantityLost': lostQty,
    });
  }

  void _showDeleteDialog(String itemId, String itemName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.confirmDeletion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          '${l10n.areYouSureDelete} $itemName?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              _apiService.deleteInventoryItem(itemId);
              Navigator.pop(ctx);
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
