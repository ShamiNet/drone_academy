import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_inventory_item_screen.dart';
import 'package:drone_academy/utils/snackbar_helper.dart'; // تأكد من وجود هذا الملف
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageInventoryScreen extends StatefulWidget {
  const ManageInventoryScreen({super.key});

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230);
    const activeTabColor = Color(
      0xFF8FA1B4,
    ); // لون التبويب النشط (تقريبي من الصورة)

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        toolbarHeight: 0, // إخفاء الـ AppBar العلوي لأننا نستخدم التبويبات فقط
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue, // اللون الأزرق للنص النشط
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'قائمة المخزون', icon: Icon(Icons.list_alt)),
            Tab(text: 'العمليات', icon: Icon(Icons.swap_horiz)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- التبويب الأول: قائمة المخزون (تعديل وحذف) ---
          _buildInventoryListTab(cardColor),
          // --- التبويب الثاني: العمليات (استعارة وإرجاع) ---
          _buildOperationsTab(cardColor),
        ],
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
    );
  }

  // --- ودجت التبويب الأول ---
  Widget _buildInventoryListTab(Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final data = item.data() as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  // أيقونة الحذف (أحمر)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFE53935)),
                    onPressed: () => item.reference.delete(),
                  ),
                  // أيقونة التعديل (أزرق)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF42A5F5)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditInventoryItemScreen(item: item),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // النصوص
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        data['name'] ?? 'Item',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'الكمية المتاحة: ${data['availableQuantity']} / ${data['totalQuantity']}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- ودجت التبويب الثاني (العمليات) ---
  Widget _buildOperationsTab(Color cardColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('inventory')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final data = item.data() as Map<String, dynamic>;
            final total = data['totalQuantity'] as int? ?? 1;
            final available = data['availableQuantity'] as int? ?? 0;
            final double percent = (available / total).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الأزرار
                      Row(
                        children: [
                          // زر إرجاع (داكن بحدود)
                          OutlinedButton(
                            onPressed: () =>
                                _showOperationDialog(item, isCheckout: false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('إرجاع'),
                          ),
                          const SizedBox(width: 8),
                          // زر استعارة (أزرق فاتح ممتلئ)
                          ElevatedButton(
                            onPressed: () =>
                                _showOperationDialog(item, isCheckout: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF90CAF9),
                              foregroundColor: Colors.black, // نص أسود
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('استعارة'),
                          ),
                        ],
                      ),
                      // العنوان والكمية
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            data['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                  // شريط التقدم (أخضر)
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

  // نافذة العمليات
  Future<void> _showOperationDialog(
    DocumentSnapshot item, {
    required bool isCheckout,
  }) async {
    final controller = TextEditingController();
    final data = item.data() as Map<String, dynamic>;
    final String title = isCheckout ? 'استعارة' : 'إرجاع';
    final int maxQty = isCheckout
        ? data['availableQuantity']
        : (data['totalQuantity'] - data['availableQuantity']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          '$title ${data['name']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'الحد الأقصى: $maxQty',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'الكمية',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(controller.text) ?? 0;
              if (qty > 0 && qty <= maxQty) {
                // تحديث المخزون
                final newAvailable = isCheckout
                    ? data['availableQuantity'] - qty
                    : data['availableQuantity'] + qty;

                item.reference.update({'availableQuantity': newAvailable});

                // تسجيل العملية في السجل (Inventory Log)
                FirebaseFirestore.instance.collection('inventory_log').add({
                  'itemId': item.id,
                  'itemName': data['name'],
                  'userId': FirebaseAuth.instance.currentUser?.uid,
                  'userName':
                      FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
                  'type': isCheckout ? 'checkout' : 'return',
                  'quantity': qty,
                  'date': Timestamp.now(),
                });

                Navigator.pop(ctx);
                showCustomSnackBar(
                  context,
                  'تمت العملية بنجاح',
                  isError: false,
                );
              } else {
                showCustomSnackBar(context, 'الكمية غير صالحة');
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
