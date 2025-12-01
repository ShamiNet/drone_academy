import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
// import 'package:drone_academy/screens/user_details_screen.dart'; // يمكن تفعيله بعد تحديث تلك الشاشة
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة
import 'package:drone_academy/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:graphview/GraphView.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum NodeOption { viewProfile, edit, addSubordinate, delete }

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
  final GlobalKey _viewerKey = GlobalKey();
  bool _initialLayoutDone = false;

  // استخدام قائمة ديناميكية بدلاً من QuerySnapshot
  late Future<List<dynamic>> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = _fetchUsers();
  }

  Future<List<dynamic>> _fetchUsers() {
    return _apiService.fetchUsers();
  }

  void _refreshChart() {
    setState(() {
      _futureUsers = _fetchUsers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  Future<Uint8List?> _captureChartAsPng() async {
    try {
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  Future<void> _captureAndSharePdf() async {
    final pngBytes = await _captureChartAsPng();
    if (pngBytes == null || !mounted) return;

    final doc = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);
    final fontData = await DefaultAssetBundle.of(
      context,
    ).load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (pw.Context context) {
          return pw.Center(child: pw.Image(pdfImage));
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  Future<void> _captureAndSaveImage() async {
    final pngBytes = await _captureChartAsPng();
    if (pngBytes == null || !mounted) {
      showCustomSnackBar(context, 'Failed to capture screenshot.');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/chart.png').create();
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path, album: 'Drone Academy');
      if (mounted) {
        showCustomSnackBar(
          context,
          'Screenshot saved to gallery!',
          isError: false,
        );
      }
    } catch (e) {
      print('Error saving image: $e');
      if (mounted) {
        showCustomSnackBar(context, 'Failed to save screenshot.');
      }
    }
  }

  void _showNodeOptionsDialog(
    Map<String, dynamic> user,
    List<dynamic> allUsers,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.person_search),
              title: Text(l10n.editProfile),
              onTap: () {
                Navigator.pop(context);
                // تم تعطيل الانتقال مؤقتاً حتى يتم تحديث UserDetailsScreen لتقبل Map
                // Navigator.push(context, MaterialPageRoute(builder: (context) => UserDetailsScreen(userData: user)));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Coming soon via API")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(user, allUsers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addNodeBelow),
              onTap: () {
                Navigator.pop(context);
                _showSelectSubordinateDialog(user, allUsers);
              },
            ),
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

  void _showEditUserDialog(
    Map<String, dynamic> user,
    List<dynamic> allUsers,
  ) async {
    String currentRole = user['role'] ?? 'trainee';
    String? currentParentId = user['parentId'];
    final userId = user['id'] ?? user['uid'];

    final potentialParents = allUsers.where((u) {
      final uId = u['id'] ?? u['uid'];
      return uId != userId;
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${l10n.edit} ${user['displayName']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.role,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: currentRole,
                      isExpanded: true,
                      items: ['admin', 'trainer', 'trainee'].map((String role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null)
                          setDialogState(() => currentRole = newValue);
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.selectNewParent,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String?>(
                      hint: const Text('Top Level'),
                      value: currentParentId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Top Level'),
                        ),
                        ...potentialParents.map((u) {
                          return DropdownMenuItem<String>(
                            value: u['id'] ?? u['uid'],
                            child: Text(u['displayName'] ?? 'Unknown'),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() => currentParentId = newValue);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _apiService.updateUser({
                      'uid': userId,
                      'role': currentRole,
                      'parentId': currentParentId ?? '',
                    });
                    Navigator.pop(context);
                    if (mounted) {
                      showCustomSnackBar(
                        context,
                        'User updated!',
                        isError: false,
                      );
                      _refreshChart();
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    final userId = user['id'] ?? user['uid'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text('${l10n.areYouSureDelete} (${user['displayName']})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await _apiService.deleteUser(userId);
              Navigator.pop(context);
              if (mounted) {
                showCustomSnackBar(context, 'User deleted!', isError: false);
                _refreshChart();
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSelectSubordinateDialog(
    Map<String, dynamic> parentUser,
    List<dynamic> allUsers,
  ) async {
    final parentId = parentUser['id'] ?? parentUser['uid'];

    // فلترة المستخدمين غير المعينين
    final unassignedUsers = allUsers.where((user) {
      final uId = user['id'] ?? user['uid'];
      final pId = user['parentId'];
      return uId != parentId && (pId == null || pId.isEmpty);
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addNodeBelow),
          content: SizedBox(
            width: double.maxFinite,
            child: unassignedUsers.isEmpty
                ? Text(l10n.noOtherNodesAvailable)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: unassignedUsers.length,
                    itemBuilder: (context, index) {
                      final user = unassignedUsers[index];
                      return ListTile(
                        title: Text(user['displayName'] ?? 'Unknown'),
                        subtitle: Text(user['role'] ?? ''),
                        onTap: () async {
                          final userId = user['id'] ?? user['uid'];
                          await _apiService.updateUser({
                            'uid': userId,
                            'parentId': parentId,
                          });
                          Navigator.of(context).pop();
                          if (mounted) {
                            showCustomSnackBar(
                              context,
                              'User assigned!',
                              isError: false,
                            );
                            _refreshChart();
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usersOrgChart), // استخدام مفتاح الترجمة الصحيح
        actions: [
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddUserScreen()),
        ).then((_) => _refreshChart()),
        tooltip: l10n.addUser,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<List<dynamic>>(
          future: _futureUsers,
          builder:
              (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(l10n.noUsersFound));
                }

                final allUsers = snapshot.data!;
                final graph = Graph();
                final Map<String, Node> nodesMap = {};

                // خريطة للوصول السريع لبيانات المستخدم عبر الـ ID
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

                // التوسيط التلقائي
                if (!_initialLayoutDone) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    // (نفس منطق التوسيط السابق)
                    _transformationController.value = Matrix4.identity()
                      ..translate(100.0, 50.0)
                      ..scale(0.8);
                    _initialLayoutDone = true;
                  });
                }

                return Stack(
                  key: _viewerKey,
                  children: [
                    RepaintBoundary(
                      key: _chartKey,
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(100.0),
                        minScale: 0.1,
                        maxScale: 4.0,
                        child: GraphView(
                          graph: graph,
                          algorithm: SugiyamaAlgorithm(
                            SugiyamaConfiguration()
                              ..orientation =
                                  SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
                              ..nodeSeparation = 30
                              ..levelSeparation = 50,
                          ),
                          builder: (Node node) {
                            final docId = node.key!.value as String;
                            if (!usersDataMap.containsKey(docId))
                              return Container();

                            final data = usersDataMap[docId]!;
                            final String role = data['role'] ?? '';

                            Color nodeColor;
                            IconData roleIcon;
                            switch (role) {
                              case 'admin':
                                nodeColor = Colors.red.shade700;
                                roleIcon = Icons.shield_outlined;
                                break;
                              case 'trainer':
                                nodeColor = Colors.blue.shade700;
                                roleIcon = Icons.school_outlined;
                                break;
                              default: // trainee
                                nodeColor = Colors.green.shade700;
                                roleIcon = Icons.person_outline;
                            }

                            return GestureDetector(
                              onTap: () =>
                                  _showNodeOptionsDialog(data, allUsers),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: nodeColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      roleIcon,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['displayName'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (data['role'] != null)
                                      Text(
                                        data['role'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: FloatingActionButton(
                        mini: true,
                        tooltip: l10n.recenterView,
                        onPressed: () {
                          _transformationController.value = Matrix4.identity();
                        },
                        child: const Icon(Icons.center_focus_strong),
                      ),
                    ),
                  ],
                );
              },
        ),
      ),
    );
  }
}
