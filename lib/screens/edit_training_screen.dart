import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // يمكن حذفه إذا لم يعد مستخدماً
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/training_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:cropperx/cropperx.dart';

class EditTrainingScreen extends StatefulWidget {
  final Map<String, dynamic>? training;
  const EditTrainingScreen({super.key, this.training});

  @override
  State<EditTrainingScreen> createState() => _EditTrainingScreenState();
}

class _EditTrainingScreenState extends State<EditTrainingScreen> {
  final ApiService _apiService = ApiService();
  late AppLocalizations l10n;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _levelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.training != null;
  String? _imageUrl;
  bool _isUploading = false;

  // متغيرات للتدريب الجديد
  String? _currentTrainingId;

  final _cropKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _currentTrainingId = widget.training!['id'];
      _titleController.text = widget.training!['title'] ?? '';
      _descriptionController.text = widget.training!['description'] ?? '';
      _levelController.text = (widget.training!['level'] ?? 1).toString();
      _imageUrl = widget.training!['imageUrl'];
    }
  }

  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();

    if (!mounted) return;
    final Uint8List? croppedBytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(l10n.cropImage),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  final cropped = await Cropper.crop(cropperKey: _cropKey);
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
      };

      if (_isEditing || _currentTrainingId != null) {
        // تحديث
        await _apiService.updateTraining(_currentTrainingId!, data);
        if (mounted && _isEditing)
          Navigator.of(context).pop();
        else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved! You can now add steps.')),
          );
        }
      } else {
        // إنشاء جديد
        // للتبسيط نرسل ترتيب افتراضي، يمكن تحسينه لاحقاً بجلب العدد الحالي
        data['order'] = 999;

        final newId = await _apiService.addTraining(data);
        if (newId != null) {
          setState(() {
            _currentTrainingId = newId;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Created! You can now add steps.')),
            );
          }
        }
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
              backgroundColor: const Color(0xFF1E2230),
              title: Text(
                l10n.addStep,
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: stepType,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.stepType,
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.stepTitle,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    if (stepType == 'video')
                      TextFormField(
                        controller: videoUrlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.videoUrl,
                          labelStyle: const TextStyle(color: Colors.grey),
                        ),
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
                    if (titleController.text.isNotEmpty &&
                        _currentTrainingId != null) {
                      // جلب الخطوات لحساب الترتيب
                      final steps = await _apiService.fetchSteps(
                        _currentTrainingId!,
                      );

                      await _apiService.addTrainingStep(_currentTrainingId!, {
                        'title': titleController.text,
                        'type': stepType,
                        'videoUrl': videoUrlController.text,
                        'order': steps.length,
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

  void _deleteStep(String stepId) async {
    if (_currentTrainingId != null) {
      await _apiService.deleteTrainingStep(_currentTrainingId!, stepId);
    }
  }

  void _showEditStepDialog(Map<String, dynamic> step) {
    final titleController = TextEditingController(text: step['title']);
    final videoUrlController = TextEditingController(
      text: step['videoUrl'] ?? '',
    );
    String stepType = step['type'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2230),
              title: Text(
                l10n.editStep,
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: stepType,
                      dropdownColor: const Color(0xFF2C2C2C),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.stepType,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.stepTitle,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    if (stepType == 'video')
                      TextFormField(
                        controller: videoUrlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: l10n.videoUrl,
                          labelStyle: const TextStyle(color: Colors.grey),
                        ),
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
                    if (titleController.text.isNotEmpty &&
                        _currentTrainingId != null) {
                      await _apiService
                          .updateTrainingStep(_currentTrainingId!, step['id'], {
                            'title': titleController.text,
                            'type': stepType,
                            'videoUrl': videoUrlController.text,
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

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editTraining : l10n.addNewTraining),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          if (_currentTrainingId != null)
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Preview',
              onPressed: () {
                if (mounted && widget.training != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TrainingDetailsScreen(
                        // --- تم التصحيح هنا: تمرير الـ Map مباشرة ---
                        training: widget.training!,
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
      floatingActionButton: (_isEditing || _currentTrainingId != null)
          ? FloatingActionButton.extended(
              onPressed: _showAddStepDialog,
              label: Text(l10n.addStep),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFFFF9800),
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة التدريب
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      borderRadius: BorderRadius.circular(12),
                      image: _imageUrl != null && _imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(_imageUrl!),
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
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          onPressed: _pickAndUploadImage,
                          icon: const Icon(Icons.edit, color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // حقول النص
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.title,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
                      validator: (v) => v!.isEmpty ? l10n.enterTitle : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.description,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
                      maxLines: 5,
                      validator: (v) =>
                          v!.isEmpty ? l10n.enterDescription : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _levelController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: l10n.level,
                        labelStyle: const TextStyle(color: Colors.grey),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? l10n.enterLevel : null,
                    ),
                  ],
                ),
              ),

              // قائمة الخطوات (تعمل مع السيرفر الآن)
              if (_currentTrainingId != null) ...[
                const Divider(height: 32, color: Colors.grey),
                Text(
                  l10n.manageSteps,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<dynamic>>(
                  stream: _apiService.streamSteps(_currentTrainingId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final steps = snapshot.data ?? [];

                    if (steps.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noStepsYet,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: steps.length,
                      onReorder: (oldIndex, newIndex) {
                        // منطق الترتيب يمكن إضافته هنا لاحقاً
                      },
                      itemBuilder: (context, index) {
                        final step = steps[index];
                        return Dismissible(
                          key: ValueKey(step['id']),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) => _deleteStep(step['id']),
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
                            key: ValueKey(step['id']),
                            color: const Color(0xFF1E2230),
                            child: ListTile(
                              leading: Icon(
                                step['type'] == 'video'
                                    ? Icons.videocam
                                    : Icons.check_box_outline_blank,
                                color: Colors.grey,
                              ),
                              title: Text(
                                step['title'],
                                style: const TextStyle(color: Colors.white),
                              ),
                              onTap: () => _showEditStepDialog(step),
                              trailing: ReorderableDragStartListener(
                                index: index,
                                child: const Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
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
