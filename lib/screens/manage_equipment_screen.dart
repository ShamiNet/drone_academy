import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/edit_equipment_screen.dart';
import 'package:drone_academy/screens/equipment_history_screen.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';

class ManageEquipmentScreen extends StatefulWidget {
  const ManageEquipmentScreen({super.key});

  @override
  State<ManageEquipmentScreen> createState() => _ManageEquipmentScreenState();
}

class _ManageEquipmentScreenState extends State<ManageEquipmentScreen> {
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  // --- ألوان الحالة (مطابقة للصورة) ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF4CAF50); // أخضر (متاح)
      case 'inUse':
        return const Color(0xFFFF9800); // برتقالي (قيد الاستخدام)
      case 'inMaintenance':
        return const Color(0xFFF44336); // أحمر (في الصيانة)
      default:
        return Colors.grey;
    }
  }

  // --- ترجمة النصوص ---
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

  // --- أيقونات الأنواع ---
  IconData _getIconForType(String type) {
    switch (type) {
      case 'drone':
        return Icons.flight;
      case 'battery':
        return Icons.battery_std; // أيقونة بطارية
      case 'controller':
        return Icons.gamepad;
      default:
        return Icons.build;
    }
  }

  Future<void> _showDeleteConfirmationDialog(DocumentSnapshot item) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          title: Text(
            l10n.confirmDeletion,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            '${l10n.areYouSureDelete} ${item['name']}?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                l10n.cancel,
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
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

  @override
  Widget build(BuildContext context) {
    // الألوان المستوحاة من التصميم الداكن
    const bgColor = Color(0xFF111318);
    const cardColor = Color(0xFF1E2230); // لون خلفية القوائم

    return Scaffold(
      backgroundColor: bgColor,

      // زر الإضافة العائم (برتقالي)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditEquipmentScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF9800),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.startFloat, // يسار الشاشة (للعربية)

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

          // تجميع المعدات حسب النوع
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
            padding: const EdgeInsets.all(16),
            itemCount: sortedTypes.length,
            itemBuilder: (context, index) {
              final type = sortedTypes[index];
              final items = equipmentByType[type]!;

              // حاوية المجموعة (الكارد الكبير)
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Theme(
                  // إزالة الخط الفاصل الافتراضي
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    collapsedIconColor: Colors.grey,
                    iconColor: const Color(0xFF8FA1B4), // لون السهم
                    // عنوان المجموعة (الأيقونة الزرقاء والنص)
                    title: Row(
                      children: [
                        // الأيقونة الدائرية (يمين)
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(
                            0xFF3F51B5,
                          ).withOpacity(0.2), // خلفية زرقاء شفافة
                          child: Icon(
                            _getIconForType(type),
                            color: const Color(0xFF5C6BC0),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // اسم النوع والعدد
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

                    // قائمة العناصر داخل المجموعة
                    children: items.map((item) {
                      final data = item.data() as Map<String, dynamic>;
                      final imageUrl = data['imageUrl'];
                      final status = data['status'] ?? 'available';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          // خط فاصل خفيف بين العناصر
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // 1. الصورة (يمين - Leading)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EquipmentHistoryScreen(
                                      equipmentId: item.id,
                                      equipmentName: data['name'] ?? '',
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey.shade800,
                                backgroundImage:
                                    (imageUrl != null && imageUrl.isNotEmpty)
                                    ? CachedNetworkImageProvider(imageUrl)
                                    : null,
                                child: (imageUrl == null || imageUrl.isEmpty)
                                    ? Icon(
                                        _getIconForType(data['type']),
                                        color: Colors.grey,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 2. النصوص (الاسم والنوع)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _translateKey(data['type'] ?? 'other'),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 3. أزرار التحكم والحالة (يسار - Trailing)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // شارة الحالة (الكبسولة الملونة)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.2), // خلفية شفافة
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getStatusColor(status),
                                      width: 1,
                                    ), // حدود ملونة
                                  ),
                                  child: Text(
                                    _translateKey(status),
                                    style: TextStyle(
                                      color: _getStatusColor(
                                        status,
                                      ), // لون النص نفس لون الحدود
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // زر التعديل (قلم)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditEquipmentScreen(
                                          equipment: item,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Icon(
                                    Icons.edit,
                                    color: Color(0xFF64B5F6),
                                    size: 20,
                                  ), // أزرق فاتح
                                ),
                                const SizedBox(width: 12),
                                // زر الحذف (سلة مهملات)
                                InkWell(
                                  onTap: () =>
                                      _showDeleteConfirmationDialog(item),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Color(0xFFEF5350),
                                    size: 20,
                                  ), // أحمر فاتح
                                ),
                              ],
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
