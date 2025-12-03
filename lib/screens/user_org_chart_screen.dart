import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math'; // للحسابات الرياضية
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:graphview/GraphView.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class UserOrgChartScreen extends StatefulWidget {
  const UserOrgChartScreen({super.key});

  @override
  State<UserOrgChartScreen> createState() => _UserOrgChartScreenState();
}

class _UserOrgChartScreenState extends State<UserOrgChartScreen> {
  final ApiService _apiService = ApiService();
  final TransformationController _transformationController =
      TransformationController();
  late AppLocalizations l10n;
  final GlobalKey _chartKey = GlobalKey();

  // مفتاح للـ GraphView لحساب حجم المحتوى
  final GlobalKey _graphViewKey = GlobalKey();

  String? _highlightedUserId;
  late Future<List<dynamic>> _futureUsers;

  final Graph graph = Graph();
  final SugiyamaConfiguration builder = SugiyamaConfiguration()
    ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
    ..nodeSeparation = 40
    ..levelSeparation = 80;

  @override
  void initState() {
    super.initState();
    _refreshChart();
  }

  void _refreshChart() {
    setState(() {
      _futureUsers = _apiService.fetchUsers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  // --- دالة "احتواء الشاشة" المحسنة ---
  void _fitToScreen({double? customScale}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? graphBox =
          _graphViewKey.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? containerBox =
          _chartKey.currentContext?.findRenderObject() as RenderBox?;

      if (graphBox != null && containerBox != null) {
        final graphSize = graphBox.size;
        final containerSize = containerBox.size;

        if (graphSize.width == 0 || graphSize.height == 0) return;

        // تحديد نسبة التقريب
        double scale;
        if (customScale != null) {
          scale = customScale;
        } else {
          // حساب النسبة تلقائياً
          final double scaleX = containerSize.width / graphSize.width;
          final double scaleY = containerSize.height / graphSize.height;
          scale = min(scaleX, scaleY) * 0.9; // هامش أمان
        }

        // حساب الإزاحة للتوسط
        final double dx = (containerSize.width - graphSize.width * scale) / 2;
        final double dy = (containerSize.height - graphSize.height * scale) / 2;

        // تطبيق التحويل
        _transformationController.value = Matrix4.identity()
          ..translate(dx, dy)
          ..scale(scale);
      }
    });
  }

  // --- أدوات التصدير ---
  Future<void> _captureAndSaveImage() async {
    try {
      RenderRepaintBoundary? boundary =
          _chartKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/org_chart_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path, album: 'Drone Academy');
      if (mounted)
        showCustomSnackBar(context, 'تم حفظ الصورة في المعرض!', isError: false);
    } catch (e) {
      if (mounted) showCustomSnackBar(context, 'فشل حفظ الصورة: $e');
    }
  }

  Future<void> _captureAndSharePdf() async {
    try {
      RenderRepaintBoundary? boundary =
          _chartKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final doc = pw.Document();
      final pdfImage = pw.MemoryImage(pngBytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) => pw.Center(child: pw.Image(pdfImage)),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      if (mounted) showCustomSnackBar(context, 'فشل إنشاء PDF: $e');
    }
  }

  void _showSearchDialog(List<dynamic> users) {
    TextEditingController searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = users.where((u) {
            final name = (u['displayName'] ?? '').toString().toLowerCase();
            return name.contains(searchCtrl.text.toLowerCase());
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2230),
            title: const Text(
              "بحث عن مستخدم",
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "اكتب الاسم...",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (user['photoUrl'] != null &&
                                    user['photoUrl'].isNotEmpty)
                                ? CachedNetworkImageProvider(user['photoUrl'])
                                : null,
                            child: (user['photoUrl'] == null)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user['displayName'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            this.setState(() {
                              _highlightedUserId = user['id'] ?? user['uid'];
                            });
                            Navigator.pop(context);
                            showCustomSnackBar(
                              context,
                              "تم تحديد المستخدم: ${user['displayName']}",
                              isError: false,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        title: Text(l10n.usersOrgChart),
        backgroundColor: const Color(0xFF111318),
        elevation: 0,
        actions: [
          // زر القائمة للتحكم في الحجم
          PopupMenuButton<double>(
            icon: const Icon(Icons.zoom_in_map),
            tooltip: "تغيير حجم العرض",
            color: const Color(0xFF1E2230), // لون الخلفية
            onSelected: (value) => _fitToScreen(customScale: value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text(
                  "احتواء تلقائي (Fit)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 1.0,
                child: Text(
                  "حجم أصلي (100%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 0.9,
                child: Text(
                  "تصغير (90%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 0.7,
                child: Text(
                  "تصغير (70%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 0.5,
                child: Text(
                  "تصغير (50%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 0.3,
                child: Text(
                  "تصغير (30%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 0.1,
                child: Text(
                  "تصغير (10%)",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "بحث",
            onPressed: () =>
                _futureUsers.then((users) => _showSearchDialog(users)),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.exportAsPdf,
            onPressed: _captureAndSharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: l10n.saveAsImage,
            onPressed: _captureAndSaveImage,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "centerBtn",
            backgroundColor: Colors.grey.shade800,
            onPressed: () =>
                _fitToScreen(customScale: null), // إعادة التوسيط التلقائي
            tooltip: l10n.recenterView,
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "addBtn",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddUserScreen()),
            ).then((_) => _refreshChart()),
            tooltip: l10n.addUser,
            backgroundColor: const Color(0xFFFF9800),
            child: const Icon(Icons.add, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _futureUsers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noUsersFound,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final allUsers = snapshot.data!;
                graph.nodes.clear();
                graph.edges.clear();
                final Map<String, Node> nodesMap = {};
                final Map<String, Map<String, dynamic>> usersDataMap = {};

                for (var user in allUsers) {
                  final id = user['id'] ?? user['uid'];
                  if (id != null) {
                    nodesMap[id] = Node.Id(id);
                    graph.addNode(nodesMap[id]!);
                    usersDataMap[id] = user as Map<String, dynamic>;
                  }
                }

                for (var user in allUsers) {
                  final id = user['id'] ?? user['uid'];
                  final parentId = user['parentId'] as String?;
                  if (parentId != null &&
                      parentId.isNotEmpty &&
                      nodesMap.containsKey(parentId) &&
                      nodesMap.containsKey(id)) {
                    graph.addEdge(nodesMap[parentId]!, nodesMap[id]!);
                  }
                }

                // استدعاء التوسيط التلقائي عند اكتمال بناء الرسم لأول مرة
                if (_chartKey.currentContext == null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _fitToScreen(),
                  );
                }

                return InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(
                    500,
                  ), // هامش كبير للسماح بالحركة
                  minScale: 0.001,
                  maxScale: 6.0,
                  child: RepaintBoundary(
                    key: _chartKey,
                    child: Center(
                      child: GraphView(
                        key: _graphViewKey,
                        graph: graph,
                        algorithm: SugiyamaAlgorithm(builder),
                        paint: Paint()
                          ..color = Colors.grey.withOpacity(0.3)
                          ..strokeWidth = 1.5
                          ..style = PaintingStyle.stroke,
                        builder: (Node node) {
                          final id = node.key!.value as String;
                          final user = usersDataMap[id]!;
                          return _buildNodeWidget(user, allUsers);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // مفتاح الألوان (Legend)
          Container(
            color: const Color(0xFF1E2230),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem("مدير عام", const Color(0xFFFFD700)),
                _buildLegendItem("مدير", const Color(0xFFFF5252)),
                _buildLegendItem("مدرب", const Color(0xFF448AFF)),
                _buildLegendItem("متدرب", const Color(0xFF69F0AE)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> user, List<dynamic> allUsers) {
    final String role = user['role'] ?? 'trainee';
    final String name = user['displayName'] ?? 'Unknown';
    final String? photoUrl = user['photoUrl'];
    final bool isHighlighted =
        (user['id'] ?? user['uid']) == _highlightedUserId;

    Color startColor, endColor;
    IconData roleIcon;

    switch (role.toLowerCase()) {
      case 'owner':
        startColor = const Color(0xFFFFD700);
        endColor = const Color(0xFFFFA000);
        roleIcon = Icons.workspace_premium;
        break;
      case 'admin':
        startColor = const Color(0xFFFF5252);
        endColor = const Color(0xFFD32F2F);
        roleIcon = Icons.shield;
        break;
      case 'trainer':
        startColor = const Color(0xFF448AFF);
        endColor = const Color(0xFF1976D2);
        roleIcon = Icons.school;
        break;
      default:
        startColor = const Color(0xFF69F0AE);
        endColor = const Color(0xFF388E3C);
        roleIcon = Icons.person;
    }

    return InkWell(
      onTap: () => _showNodeOptionsDialog(user, allUsers),
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.all(4),
          width: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isHighlighted
                ? Border.all(color: Colors.white, width: 3)
                : null,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E2230).withOpacity(0.9),
                const Color(0xFF111318).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: endColor.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 50,
                decoration: BoxDecoration(
                  color: endColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: (photoUrl == null)
                    ? Icon(roleIcon, color: endColor, size: 26)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                role.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: startColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeOptionsDialog(
    Map<String, dynamic> user,
    List<dynamic> allUsers,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.person_search, color: Colors.blue),
              title: Text(
                l10n.editProfile,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailsScreen(userData: user),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.amber),
              title: Text(
                l10n.edit,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user, allUsers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_link, color: Colors.green),
              title: Text(
                l10n.addNodeBelow,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showSelectSubordinateDialog(user, allUsers);
              },
            ),
            if (user['role'] != 'owner')
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  l10n.delete,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteUserDialog(user);
                },
              ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user, List<dynamic> allUsers) {
    String currentRole = user['role'] ?? 'trainee';
    String? currentParentId = user['parentId'];
    if (currentParentId == "") currentParentId = null;
    final userId = user['id'] ?? user['uid'];
    final potentialParents = allUsers
        .where((u) => (u['id'] ?? u['uid']) != userId)
        .toList();

    if (currentParentId != null) {
      final exists = potentialParents.any(
        (u) => (u['id'] ?? u['uid']) == currentParentId,
      );
      if (!exists) currentParentId = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          title: const Text(
            "تعديل العقدة",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: currentRole,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                items: ['admin', 'trainer', 'trainee']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setSt(() => currentRole = v!),
              ),
              const SizedBox(height: 10),
              DropdownButton<String?>(
                value: currentParentId,
                dropdownColor: const Color(0xFF2C2C2C),
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  "اختر المسؤول",
                  style: TextStyle(color: Colors.grey),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("بدون مسؤول"),
                  ),
                  ...potentialParents.map(
                    (p) => DropdownMenuItem(
                      value: p['id'] ?? p['uid'],
                      child: Text(p['displayName'] ?? 'Unknown'),
                    ),
                  ),
                ],
                onChanged: (v) => setSt(() => currentParentId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _apiService.updateUser({
                  'uid': userId,
                  'role': currentRole,
                  'parentId': currentParentId ?? '',
                });
                Navigator.pop(ctx);
                _refreshChart();
              },
              child: const Text("حفظ"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectSubordinateDialog(
    Map<String, dynamic> parentUser,
    List<dynamic> allUsers,
  ) {
    final parentId = parentUser['id'] ?? parentUser['uid'];

    // إظهار جميع المستخدمين ما عدا الشخص نفسه
    final potentialSubordinates = allUsers
        .where((u) => (u['id'] ?? u['uid']) != parentId)
        .toList();
    potentialSubordinates.sort(
      (a, b) => (a['displayName'] ?? '').compareTo(b['displayName'] ?? ''),
    );

    TextEditingController searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = potentialSubordinates.where((u) {
            final name = (u['displayName'] ?? '').toString().toLowerCase();
            return name.contains(searchCtrl.text.toLowerCase());
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2230),
            title: Text(
              l10n.addNodeBelow,
              style: const TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "بحث...",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final u = filtered[idx];
                        final currentParentId = u['parentId'];
                        String info = u['role'] ?? '';
                        if (currentParentId != null &&
                            currentParentId.toString().isNotEmpty) {
                          final p = allUsers.firstWhere(
                            (user) =>
                                (user['id'] ?? user['uid']) == currentParentId,
                            orElse: () => null,
                          );
                          if (p != null)
                            info += " | حالياً مع: ${p['displayName']}";
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                (u['photoUrl'] != null && u['photoUrl'] != '')
                                ? CachedNetworkImageProvider(u['photoUrl'])
                                : null,
                            child: (u['photoUrl'] == null)
                                ? const Icon(Icons.person, size: 16)
                                : null,
                            radius: 16,
                          ),
                          title: Text(
                            u['displayName'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            info,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                          onTap: () async {
                            await _apiService.updateUser({
                              'uid': u['id'] ?? u['uid'],
                              'parentId': parentId,
                            });
                            Navigator.pop(context);
                            showCustomSnackBar(
                              context,
                              "تم النقل بنجاح",
                              isError: false,
                            );
                            _refreshChart();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    final userId = user['id'] ?? user['uid'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.confirmDeletion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          "${l10n.areYouSureDelete} (${user['displayName']})?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _apiService.deleteUser(userId);
              Navigator.pop(ctx);
              _refreshChart();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
