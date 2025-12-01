import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:graphview/GraphView.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> {
  final ApiService _apiService = ApiService(); // استخدام الخدمة
  late AppLocalizations l10n;
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _chartKey = GlobalKey();

  // متغير لتخزين البيانات وتحديثها
  late Future<List<dynamic>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  void _refreshNodes() {
    setState(() {
      _nodesFuture = _apiService.fetchOrgNodes();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  Future<void> _captureAndSharePdf() async {
    try {
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

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
    } catch (e) {
      print('Error capturing or sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate PDF.')),
        );
      }
    }
  }

  void _showNodeOptionsDialog(Map<String, dynamic> node) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.editNode),
              onTap: () {
                Navigator.pop(context);
                _showEditOrAddNodeDialog(node: node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.move_up),
              title: Text(l10n.moveNode),
              onTap: () {
                Navigator.pop(context);
                _showChangeParentDialog(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.addNodeBelow),
              onTap: () {
                Navigator.pop(context);
                _showEditOrAddNodeDialog(parentNodeId: node['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(
                l10n.deleteNode,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteNodeDialog(node);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditOrAddNodeDialog({
    Map<String, dynamic>? node,
    String? parentNodeId,
  }) {
    final bool isEditing = node != null;
    final nameController = TextEditingController(
      text: isEditing ? node['name'] : '',
    );
    final roleController = TextEditingController(
      text: isEditing ? node['role'] : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? l10n.editNode : l10n.addNewNode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              TextField(
                controller: roleController,
                decoration: InputDecoration(labelText: l10n.role),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text;
                final role = roleController.text;
                if (name.isNotEmpty) {
                  if (isEditing) {
                    await _apiService.updateOrgNode(node['id'], {
                      'name': name,
                      'role': role,
                    });
                  } else {
                    await _apiService.addOrgNode({
                      'name': name,
                      'role': role,
                      'parentId': parentNodeId,
                    });
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    _refreshNodes();
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteNodeDialog(Map<String, dynamic> node) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDeletion),
        content: Text("${l10n.areYouSureDelete} (${node['name']})"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              await _apiService.deleteOrgNode(node['id']);
              if (mounted) {
                Navigator.pop(context);
                _refreshNodes();
              }
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showChangeParentDialog(Map<String, dynamic> nodeToMove) async {
    // جلب القائمة الحالية لاستبعاد العقدة نفسها
    final allNodes = await _apiService.fetchOrgNodes();
    final potentialParents = allNodes
        .where((doc) => doc['id'] != nodeToMove['id'])
        .toList();

    if (potentialParents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noOtherNodesAvailable)));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectNewParent),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: potentialParents.length,
              itemBuilder: (context, index) {
                final parentNode = potentialParents[index];
                return ListTile(
                  title: Text(parentNode['name']),
                  onTap: () async {
                    await _apiService.updateOrgNode(nodeToMove['id'], {
                      'parentId': parentNode['id'],
                    });
                    if (mounted) {
                      Navigator.of(context).pop();
                      _showSuccessAndReload();
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

  void _showSuccessAndReload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Node moved successfully!'),
        duration: Duration(seconds: 1),
      ),
    );
    _refreshNodes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.organizationalStructure),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export as PDF',
            onPressed: _captureAndSharePdf,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _nodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: ElevatedButton(
                onPressed: () => _showEditOrAddNodeDialog(parentNodeId: ''),
                child: Text(l10n.addRootNode),
              ),
            );
          }

          final graph = Graph();
          final Map<String, Node> nodesMap = {};
          final Map<String, Map<String, dynamic>> docsMap = {
            for (var doc in snapshot.data!) doc['id']: doc,
          };

          // إنشاء العقد (Nodes)
          for (var doc in snapshot.data!) {
            final id = doc['id'];
            final node = Node.Id(id);
            nodesMap[id] = node;
            graph.addNode(node);
          }

          // إنشاء الروابط (Edges)
          for (var doc in snapshot.data!) {
            final parentId = doc['parentId'] as String?;
            if (parentId != null &&
                parentId.isNotEmpty &&
                nodesMap.containsKey(parentId)) {
              graph.addEdge(nodesMap[parentId]!, nodesMap[doc['id']]!);
            }
          }

          final algorithm = SugiyamaAlgorithm(
            SugiyamaConfiguration()
              ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
              ..nodeSeparation = 30
              ..levelSeparation = 50,
          );

          return Stack(
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
                    algorithm: algorithm,
                    builder: (Node node) {
                      final docId = node.key!.value as String;
                      if (!docsMap.containsKey(docId)) {
                        return Container();
                      }
                      final data = docsMap[docId]!;

                      return GestureDetector(
                        onTap: () => _showNodeOptionsDialog(data),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
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
                              Text(
                                data['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (data['role'] != null &&
                                  data['role'].isNotEmpty)
                                Text(
                                  data['role'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
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
                  tooltip: 'Recenter View',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditOrAddNodeDialog(parentNodeId: ''),
        child: const Icon(Icons.add),
        tooltip: l10n.addRootNode,
      ),
    );
  }
}
