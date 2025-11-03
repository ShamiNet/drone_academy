import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/training_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // 1. استيراد هذه الحزمة
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cropperx/cropperx.dart'; // 2. استيراد الحزمة الجديدة
import 'package:cached_network_image/cached_network_image.dart'; // استيراد هذه الحزمة
import 'package:cloudinary_public/cloudinary_public.dart';

class EditTrainingScreen extends StatefulWidget {
  final DocumentSnapshot? training;
  const EditTrainingScreen({super.key, this.training});

  @override
  State<EditTrainingScreen> createState() => _EditTrainingScreenState();
}

class _EditTrainingScreenState extends State<EditTrainingScreen> {
  late AppLocalizations l10n;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _levelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.training != null;
  String? _imageUrl;
  bool _isUploading = false;

  // --- بداية التعديل: استخدام GlobalKey بدون نوع ---
  final _cropKey = GlobalKey();
  // --- نهاية التعديل ---

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.training!['title'];
      _descriptionController.text = widget.training!['description'];
      _levelController.text = widget.training!['level'].toString();
      _imageUrl = widget.training!['imageUrl'];
    }
  }

  // --- دالة اختيار وقص الصورة المعدلة ---
  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();

    // فتح شاشة القص
    final Uint8List? croppedBytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(l10n.cropImage ?? 'Crop Image'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  // جعل الدالة غير متزامنة
                  // دالة القص عند الضغط على زر التأكيد
                  final cropped = await Cropper.crop(
                    // استخدام await
                    cropperKey: _cropKey,
                  );
                  Navigator.pop(context, cropped);
                },
              ),
            ],
          ),
          body: Center(
            child: Cropper(
              cropperKey: _cropKey,
              image: Image.memory(imageBytes),
              aspectRatio: 16 / 9,
            ),
          ),
        ),
      ),
    );

    if (croppedBytes != null) {
      setState(() => _isUploading = true);

      final cloudinary = CloudinaryPublic('dvocrpapc', 'ml_default');

      try {
        final String fileName =
            'training_image_${DateTime.now().millisecondsSinceEpoch}';

        final CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            croppedBytes,
            identifier: fileName,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        setState(() {
          _imageUrl = response.secureUrl;
          _isUploading = false;
        });
      } catch (e) {
        print('Failed to upload image: $e');
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  Future<void> _saveTraining() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'level': int.tryParse(_levelController.text) ?? 1,
        'imageUrl': _imageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      String? docId = widget.training?.id;
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('trainings')
            .doc(docId)
            .update(data);
      } else {
        // --- بداية التعديل: إضافة حقل الترتيب عند الإنشاء ---
        final level = int.tryParse(_levelController.text) ?? 1;

        // جلب عدد التدريبات الحالية في نفس المستوى لتحديد الترتيب
        final countQuery = await FirebaseFirestore.instance
            .collection('trainings')
            .where('level', isEqualTo: level)
            .count()
            .get();
        final currentCount = countQuery.count ?? 0;

        data['order'] = currentCount; // الترتيب الجديد هو الأخير
        data['createdAt'] = FieldValue.serverTimestamp(); // حقل مفيد

        final newDoc = await FirebaseFirestore.instance
            .collection('trainings')
            .add(data);
        docId = newDoc.id; // Get the ID of the newly created training
      }
      if (mounted) {
        // If we were creating a new training, pop back to the list
        // If editing, we might want to stay, but for now we pop
        Navigator.of(context).pop();
      }
    }
  }

  void _showAddStepDialog() {
    final titleController = TextEditingController();
    final videoUrlController = TextEditingController();
    String stepType = 'checklist';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addStep),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: stepType,
                      decoration: InputDecoration(labelText: l10n.stepType),
                      items: [
                        DropdownMenuItem(
                          value: 'checklist',
                          child: Text(l10n.checklist),
                        ),
                        DropdownMenuItem(
                          value: 'video',
                          child: Text(l10n.video),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => stepType = value);
                      },
                    ),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: l10n.stepTitle),
                    ),
                    if (stepType == 'video')
                      TextFormField(
                        controller: videoUrlController,
                        decoration: InputDecoration(labelText: l10n.videoUrl),
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
                    if (titleController.text.isNotEmpty) {
                      final stepsCollection = FirebaseFirestore.instance
                          .collection('trainings')
                          .doc(widget.training!.id)
                          .collection('steps');

                      // جلب عدد الخطوات الحالية لتحديد الترتيب الجديد
                      final countQuery = await stepsCollection.count().get();
                      final currentCount = countQuery.count ?? 0;

                      await stepsCollection.add({
                        'title': titleController.text,
                        'type': stepType,
                        'videoUrl': videoUrlController.text,
                        'order': currentCount, // استخدام العدد الحالي كترتيب
                      });
                      if (mounted) Navigator.pop(context);
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

  // --- دالة جديدة لتحديث ترتيب الخطوات في Firestore ---
  Future<void> _reorderSteps(int oldIndex, int newIndex) async {
    final stepsCollection = FirebaseFirestore.instance
        .collection('trainings')
        .doc(widget.training!.id)
        .collection('steps');

    final snapshot = await stepsCollection.orderBy('order').get();
    List<DocumentSnapshot> steps = snapshot.docs;

    // تحديث الترتيب في القائمة المحلية أولاً
    final item = steps.removeAt(oldIndex);
    steps.insert(newIndex, item);

    // استخدام WriteBatch لتحديث كل المستندات في عملية واحدة
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < steps.length; i++) {
      batch.update(steps[i].reference, {'order': i});
    }

    await batch.commit();
  }

  // --- بداية الإضافة: دالة جديدة لتعديل الخطوة ---
  void _showEditStepDialog(DocumentSnapshot stepDoc) {
    final titleController = TextEditingController(text: stepDoc['title']);
    final videoUrlController = TextEditingController(
      text: stepDoc['videoUrl'] ?? '',
    );
    String stepType = stepDoc['type'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.editStep), // استخدام النص الجديد
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: stepType,
                      decoration: InputDecoration(labelText: l10n.stepType),
                      items: [
                        DropdownMenuItem(
                          value: 'checklist',
                          child: Text(l10n.checklist),
                        ),
                        DropdownMenuItem(
                          value: 'video',
                          child: Text(l10n.video),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => stepType = value);
                      },
                    ),
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: l10n.stepTitle),
                    ),
                    if (stepType == 'video')
                      TextFormField(
                        controller: videoUrlController,
                        decoration: InputDecoration(labelText: l10n.videoUrl),
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
                    if (titleController.text.isNotEmpty) {
                      // استخدام .update() لتحديث المستند الموجود
                      await stepDoc.reference.update({
                        'title': titleController.text,
                        'type': stepType,
                        'videoUrl': videoUrlController.text,
                        // 'order' يبقى كما هو
                      });
                      if (mounted) Navigator.pop(context);
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
  // --- نهاية الإضافة ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTraining : l10n.addNewTraining),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Preview',
              onPressed: () {
                if (mounted && widget.training != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingDetailsScreen(
                        training: widget.training as QueryDocumentSnapshot,
                        imageUrl:
                            _imageUrl ?? 'assets/images/drone_training_1.jpg',
                      ),
                    ),
                  );
                }
              },
            ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveTraining),
        ],
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              onPressed: _showAddStepDialog,
              label: Text(l10n.addStep),
              icon: const Icon(Icons.add),
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- قسم الصورة ---
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      image: _imageUrl != null && _imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                _imageUrl!,
                              ), // تعديل هنا
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageUrl == null || _imageUrl!.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!_isUploading)
                    IconButton(
                      onPressed: _pickAndUploadImage,
                      icon: const CircleAvatar(child: Icon(Icons.edit)),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // --- قسم الفورم ---
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: l10n.title),
                      validator: (v) => v!.isEmpty ? l10n.enterTitle : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(labelText: l10n.description),
                      maxLines: 5,
                      validator: (v) =>
                          v!.isEmpty ? l10n.enterDescription : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _levelController,
                      decoration: InputDecoration(labelText: l10n.level),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? l10n.enterLevel : null,
                    ),
                  ],
                ),
              ),

              // --- قسم إدارة الخطوات ---
              if (_isEditing) ...[
                const Divider(height: 32),
                Text(
                  l10n.manageSteps,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('trainings')
                      .doc(widget.training!.id)
                      .collection('steps')
                      .orderBy('order')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text(l10n.noStepsYet));
                    }

                    // **-- بداية التعديل --**
                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      // onReorder هو الذي يستدعي دالة الترتيب عند السحب والإفلات
                      onReorder: (oldIndex, newIndex) {
                        // Flutter قد يقوم بتعديل newIndex إذا تم سحب العنصر للأسفل
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        _reorderSteps(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final step = snapshot.data!.docs[index];
                        // كل عنصر يحتاج إلى Key فريد.
                        return Dismissible(
                          key: ValueKey(step.id), // استخدام Key فريد لكل عنصر
                          direction: DismissDirection.endToStart, // اتجاه السحب
                          // الدالة التي يتم استدعاؤها عند الحذف
                          onDismissed: (direction) {
                            FirebaseFirestore.instance
                                .collection('trainings')
                                .doc(widget.training!.id)
                                .collection('steps')
                                .doc(step.id)
                                .delete();
                            // StreamBuilder سيقوم بتحديث الواجهة تلقائياً
                          },
                          // الخلفية التي تظهر أثناء السحب
                          background: Container(
                            color: Colors.red.shade700,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          child: Card(
                            key: ValueKey(step.id),
                            child: ListTile(
                              leading: Icon(
                                step['type'] == 'video'
                                    ? Icons.videocam
                                    : Icons.check_box_outline_blank,
                              ),
                              title: Text(step['title']),
                              // --- بداية التعديل: إضافة onTap ---
                              onTap: () {
                                _showEditStepDialog(step);
                              },
                              // --- نهاية التعديل ---
                              // إضافة أيقونة السحب في نهاية العنصر
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    // **-- نهاية التعديل --**
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
