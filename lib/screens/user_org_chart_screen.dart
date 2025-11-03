import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/add_user_screen.dart';
import 'package:drone_academy/screens/user_details_screen.dart';
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
  final TransformationController _transformationController =
      TransformationController();
  late AppLocalizations l10n;
  final GlobalKey _chartKey = GlobalKey();
  // --- بداية الإصلاح: استخدام متغير حالة للـ Future ---
  final GlobalKey _viewerKey = GlobalKey();
  bool _initialLayoutDone = false;

  late Future<QuerySnapshot> _futureUsers;

  @override
  void initState() {
    super.initState();
    _futureUsers = _fetchUsers();
  }

  Future<QuerySnapshot> _fetchUsers() {
    return FirebaseFirestore.instance.collection('users').get();
  }

  void _refreshChart() {
    setState(() {
      _futureUsers = _fetchUsers();
    });
  }
  // --- نهاية الإصلاح ---

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
    DocumentSnapshot userDoc,
    List<DocumentSnapshot> allUsers,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailsScreen(userDoc: userDoc),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _showEditUserDialog(userDoc, allUsers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addNodeBelow),
              onTap: () {
                Navigator.pop(context);
                _showSelectSubordinateDialog(userDoc, allUsers);
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
                _showDeleteUserDialog(userDoc);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(
    DocumentSnapshot user,
    List<DocumentSnapshot> allUsers,
  ) async {
    String currentRole = user['role'];
    String? currentParentId =
        (user.data() as Map<String, dynamic>).containsKey('parentId')
        ? user['parentId']
        : null;
    final potentialParents = allUsers.where((u) => u.id != user.id).toList();

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
                        ...potentialParents.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['displayName']),
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
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.id)
                        .update({
                          'role': currentRole,
                          'parentId': currentParentId ?? '',
                        });
                    Navigator.pop(context);
                    // Force a rebuild of the FutureBuilder
                    if (mounted) {
                      showCustomSnackBar(
                        context,
                        'User updated!',
                        isError: false,
                      );
                      // setState(() {}); // Replaced with _refreshChart
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

  void _showDeleteUserDialog(DocumentSnapshot user) {
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
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.id)
                  .delete();
              Navigator.pop(context);
              // Force a rebuild of the FutureBuilder
              if (mounted) {
                showCustomSnackBar(context, 'User deleted!', isError: false);
                _refreshChart(); // --- استخدام الدالة الجديدة ---
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSelectSubordinateDialog(
    DocumentSnapshot parentDoc,
    List<DocumentSnapshot> allUsers,
  ) async {
    // --- NEW: Filter for unassigned users ---
    final unassignedUsers = allUsers.where((user) {
      final data = user.data() as Map<String, dynamic>;
      final parentId = data.containsKey('parentId')
          ? data['parentId'] as String?
          : null;
      return user.id != parentDoc.id && (parentId == null || parentId.isEmpty);
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.addNodeBelow),
          content: SizedBox(
            width: double.maxFinite,
            child:
                unassignedUsers
                    .isEmpty // Handle empty case
                ? Text(l10n.noOtherNodesAvailable)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: unassignedUsers.length, // Use filtered list
                    itemBuilder: (context, index) {
                      final user = unassignedUsers[index]; // Use filtered list
                      return ListTile(
                        title: Text(user['displayName']),
                        subtitle: Text(user['role']),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.id)
                              .update({'parentId': parentDoc.id});
                          Navigator.of(context).pop();
                          // Force a rebuild of the FutureBuilder
                          if (mounted) {
                            showCustomSnackBar(
                              context,
                              'User assigned!',
                              isError: false,
                            );
                            _refreshChart(); // --- استخدام الدالة الجديدة ---
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
        title: Text(l10n.organizationalStructure),
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
        ).then((_) => _refreshChart()), // --- استخدام الدالة الجديدة ---
        tooltip: l10n.addUser,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<QuerySnapshot>(
          future: _futureUsers, // --- استخدام متغير الحالة ---
          builder:
              (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text(l10n.noUsersFound));
                }

                final allUsers = snapshot.data!.docs;
                final docsMap = {for (var doc in allUsers) doc.id: doc};
                final graph = Graph();
                final Map<String, Node> nodesMap = {};

                for (var doc in allUsers) {
                  nodesMap[doc.id] = Node.Id(doc.id);
                  graph.addNode(nodesMap[doc.id]!);
                }

                for (var doc in allUsers) {
                  final data = doc.data() as Map<String, dynamic>;
                  final parentId = data['parentId'] as String?;
                  if (parentId != null &&
                      parentId.isNotEmpty &&
                      nodesMap.containsKey(parentId) &&
                      nodesMap.containsKey(doc.id)) {
                    graph.addEdge(nodesMap[parentId]!, nodesMap[doc.id]!);
                  }
                }

                // --- بداية التعديل: ضبط العرض الأولي ليناسب الشاشة ---
                if (!_initialLayoutDone) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;

                    final viewerContext = _viewerKey.currentContext;
                    final chartContext = _chartKey.currentContext;

                    if (viewerContext != null && chartContext != null) {
                      final viewerBox =
                          viewerContext.findRenderObject() as RenderBox;
                      final chartBox =
                          chartContext.findRenderObject() as RenderBox;

                      final viewerSize = viewerBox.size;
                      final chartSize = chartBox.size;

                      if (chartSize.width > 0 && chartSize.height > 0) {
                        final scale =
                            (viewerSize.width / chartSize.width) <
                                (viewerSize.height / chartSize.height)
                            ? (viewerSize.width / chartSize.width)
                            : (viewerSize.height / chartSize.height);

                        // --- بداية التعديل: التوسيط الأفقي فقط ---
                        final dx =
                            (viewerSize.width - chartSize.width * scale) / 2;
                        // --- نهاية التعديل ---

                        _transformationController.value = Matrix4.identity()
                          ..translate(
                            dx,
                            20.0, // إضافة padding علوي لتحريكه للأسفل قليلاً
                          ) // استخدام dx للتوسيط الأفقي، و 50 للـ dy
                          ..scale(scale);

                        _initialLayoutDone = true;
                      }
                    }
                  });
                }
                // --- نهاية التعديل ---

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
                            if (!docsMap.containsKey(docId)) return Container();

                            final doc = docsMap[docId]!;
                            final data = doc.data() as Map<String, dynamic>;
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
                                  _showNodeOptionsDialog(doc, allUsers),
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
                                      data['displayName'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (data['role'] != null &&
                                        data['role'].isNotEmpty)
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
