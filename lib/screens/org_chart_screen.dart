import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
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

class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> {
  final ApiService _apiService = ApiService();
  final TransformationController _transformationController =
      TransformationController();
  late AppLocalizations l10n;
  final GlobalKey _chartKey = GlobalKey();
  final GlobalKey _graphViewKey = GlobalKey();

  late Future<List<dynamic>> _nodesFuture;
  String? _highlightedNodeId;

  final Graph graph = Graph();
  final SugiyamaConfiguration builder = SugiyamaConfiguration()
    ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
    ..nodeSeparation = 40
    ..levelSeparation = 80;

  // الألوان
  final Color _defaultColor = const Color(0xFF2196F3);
  final List<Color> _colorPalette = [
    const Color(0xFF2196F3),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF673AB7),
    const Color(0xFF009688),
    const Color(0xFF4CAF50),
    const Color(0xFFFFC107),
    const Color(0xFFFF5722),
    const Color(0xFF795548),
    const Color(0xFF607D8B),
  ];

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

        double scale =
            customScale ??
            min(
                  containerSize.width / graphSize.width,
                  containerSize.height / graphSize.height,
                ) *
                0.9;
        final double dx = (containerSize.width - graphSize.width * scale) / 2;
        final double dy = (containerSize.height - graphSize.height * scale) / 2;

        _transformationController.value = Matrix4.identity()
          ..translate(dx, dy)
          ..scale(scale);
      }
    });
  }

  Future<void> _captureAndSaveImage() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).hideCurrentSnackBar(); // إخفاء أي رسالة سابقة
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
        showCustomSnackBar(context, 'تم حفظ الصورة!', isError: false);
    } catch (e) {
      if (mounted) showCustomSnackBar(context, 'فشل الحفظ: $e');
    }
  }

  Future<void> _captureAndSharePdf() async {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
      if (mounted) showCustomSnackBar(context, 'فشل PDF: $e');
    }
  }

  void _showSearchDialog(List<dynamic> nodes) {
    TextEditingController searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final filtered = nodes
              .where(
                (n) => (n['name'] ?? '').toString().toLowerCase().contains(
                  searchCtrl.text.toLowerCase(),
                ),
              )
              .toList();
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2230),
            title: const Text(
              "بحث عن قسم",
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
                      hintText: "اسم القسم...",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final node = filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: node['nodeColor'] != null
                                ? Color(node['nodeColor'])
                                : _defaultColor,
                            child: const Icon(
                              Icons.apartment,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            node['name'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                            this.setState(() {
                              _highlightedNodeId = node['id'];
                            });
                            Navigator.pop(context);
                            showCustomSnackBar(
                              context,
                              "تم تحديد: ${node['name']}",
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
        title: Text(l10n.organizationalStructure),
        backgroundColor: const Color(0xFF111318),
        elevation: 0,
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.zoom_in_map),
            tooltip: "تغيير حجم العرض",
            color: const Color(0xFF1E2230),
            onSelected: (value) => _fitToScreen(customScale: value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text(
                  "احتواء تلقائي",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 1.0,
                child: Text("100%", style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 0.5,
                child: Text("50%", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () =>
                _nodesFuture.then((nodes) => _showSearchDialog(nodes)),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _captureAndSharePdf,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _captureAndSaveImage,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _nodesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          _showEditOrAddNodeDialog(parentNodeId: ''),
                      child: Text(l10n.addRootNode),
                    ),
                  );
                }

                final nodes = snapshot.data!;
                graph.nodes.clear();
                graph.edges.clear();
                final Map<String, Node> nodesMap = {};
                final Map<String, Map<String, dynamic>> dataMap = {};

                for (var nodeData in nodes) {
                  final id = nodeData['id'];
                  final node = Node.Id(id);
                  nodesMap[id] = node;
                  graph.addNode(node);
                  dataMap[id] = nodeData as Map<String, dynamic>;
                }

                for (var nodeData in nodes) {
                  final parentId = nodeData['parentId'];
                  if (parentId != null &&
                      parentId.isNotEmpty &&
                      nodesMap.containsKey(parentId) &&
                      nodesMap.containsKey(nodeData['id'])) {
                    graph.addEdge(
                      nodesMap[parentId]!,
                      nodesMap[nodeData['id']]!,
                    );
                  }
                }

                if (_chartKey.currentContext == null)
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _fitToScreen(),
                  );

                return InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(500),
                  minScale: 0.001,
                  maxScale: 5.0,
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
                          return _buildNodeWidget(dataMap[id]!);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFF1E2230),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _defaultColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text("قسم / وحدة", style: TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        // [تعديل هام] إضافة mainAxisSize.min لإصلاح خطأ SnackBar
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            mini: true,
            heroTag: "center",
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: () => _fitToScreen(),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "add",
            backgroundColor: const Color(0xFFFF9800),
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showEditOrAddNodeDialog(parentNodeId: ''),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(Map<String, dynamic> nodeData) {
    final bool isHighlighted = nodeData['id'] == _highlightedNodeId;
    Color nodeColor = _defaultColor;
    if (nodeData['nodeColor'] != null) {
      nodeColor = Color(nodeData['nodeColor']);
    }

    return InkWell(
      onTap: () => _showNodeOptionsDialog(nodeData),
      child: FadeInUp(
        duration: const Duration(milliseconds: 500),
        child: Container(
          padding: const EdgeInsets.all(8),
          width: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isHighlighted
                ? Border.all(color: Colors.white, width: 3)
                : null,
            gradient: LinearGradient(
              colors: [const Color(0xFF1E2230), const Color(0xFF111318)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: nodeColor.withOpacity(0.4),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 60,
                decoration: BoxDecoration(
                  color: nodeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.apartment, color: nodeColor, size: 30),
              const SizedBox(height: 6),
              Text(
                nodeData['name'] ?? 'Unkown',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 2,
              ),
              if (nodeData['role'] != null)
                Text(
                  nodeData['role'],
                  style: TextStyle(
                    color: nodeColor.withOpacity(0.8),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeOptionsDialog(Map<String, dynamic> node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2230),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.amber),
              title: Text(
                l10n.edit,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showEditOrAddNodeDialog(node: node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.move_up, color: Colors.blue),
              title: Text(
                l10n.moveNode,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showChangeParentDialog(node);
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
    final isEditing = node != null;
    final nameCtrl = TextEditingController(text: isEditing ? node['name'] : '');
    final roleCtrl = TextEditingController(text: isEditing ? node['role'] : '');
    int? selectedColorValue = isEditing ? node!['nodeColor'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          title: Text(
            isEditing ? l10n.editNode : l10n.addNewNode,
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l10n.name,
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                TextField(
                  controller: roleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: l10n.role,
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "لون البطاقة",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () => setSt(() => selectedColorValue = null),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ..._colorPalette.map(
                      (color) => GestureDetector(
                        onTap: () =>
                            setSt(() => selectedColorValue = color.value),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColorValue == color.value
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: selectedColorValue == color.value
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final data = {
                    'name': nameCtrl.text,
                    'role': roleCtrl.text,
                    'nodeColor': selectedColorValue,
                  };
                  if (isEditing)
                    await _apiService.updateOrgNode(node!['id'], data);
                  else {
                    data['parentId'] = parentNodeId;
                    await _apiService.addOrgNode(data);
                  }
                  Navigator.pop(ctx);
                  _refreshNodes();
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteNodeDialog(Map<String, dynamic> node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.confirmDeletion,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          "${l10n.areYouSureDelete} (${node['name']})?",
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
              await _apiService.deleteOrgNode(node['id']);
              Navigator.pop(ctx);
              _refreshNodes();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showChangeParentDialog(Map<String, dynamic> nodeToMove) async {
    final allNodes = await _apiService.fetchOrgNodes();
    final potentialParents = allNodes
        .where((n) => n['id'] != nodeToMove['id'])
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: Text(
          l10n.selectNewParent,
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: potentialParents.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(
                potentialParents[i]['name'],
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await _apiService.updateOrgNode(nodeToMove['id'], {
                  'parentId': potentialParents[i]['id'],
                });
                Navigator.pop(ctx);
                _refreshNodes();
              },
            ),
          ),
        ),
      ),
    );
  }
}
