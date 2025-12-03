import 'dart:typed_data';
import 'package:animate_do/animate_do.dart'; // مكتبة الحركات
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cropperx/cropperx.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/training_details_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  String? _currentTrainingId;
  final _cropKey = GlobalKey();

  // ألوان التصميم
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800); // برتقالي
  final Color _secondaryColor = const Color(0xFF3F51B5); // أزرق

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
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(l10n.cropImage ?? 'Crop'),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.white),
                onPressed: () async {
                  final c = await Cropper.crop(cropperKey: _cropKey);
                  Navigator.pop(context, c);
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
      try {
        final cloudinary = CloudinaryPublic('dvocrpapc', 'ml_default');
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            croppedBytes,
            identifier: 'tr_${DateTime.now().millisecondsSinceEpoch}',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        setState(() {
          _imageUrl = response.secureUrl;
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
      }
    }
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
        await _apiService.updateTraining(_currentTrainingId!, data);
        if (mounted && _isEditing)
          Navigator.of(context).pop();
        else if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم حفظ التعديلات!')));
      } else {
        data['order'] = 999;
        data['createdAt'] = DateTime.now().toIso8601String();
        final newId = await _apiService.addTraining(data);
        if (newId != null) {
          setState(() => _currentTrainingId = newId);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم الإنشاء! يمكنك الآن إضافة الخطوات.'),
              ),
            );
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
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => _buildStepDialog(
          title: l10n.addStep,
          titleController: titleController,
          videoUrlController: videoUrlController,
          stepType: stepType,
          onTypeChanged: (v) => setSt(() => stepType = v!),
          onSave: () async {
            if (titleController.text.isNotEmpty && _currentTrainingId != null) {
              final steps = await _apiService.fetchSteps(_currentTrainingId!);
              await _apiService.addTrainingStep(_currentTrainingId!, {
                'title': titleController.text,
                'type': stepType,
                'videoUrl': videoUrlController.text,
                'order': steps.length,
              });
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  void _showEditStepDialog(Map<String, dynamic> step) {
    final titleController = TextEditingController(text: step['title']);
    final videoUrlController = TextEditingController(
      text: step['videoUrl'] ?? '',
    );
    String stepType = step['type'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSt) => _buildStepDialog(
          title: l10n.editStep,
          titleController: titleController,
          videoUrlController: videoUrlController,
          stepType: stepType,
          onTypeChanged: (v) => setSt(() => stepType = v!),
          onSave: () async {
            if (titleController.text.isNotEmpty) {
              await _apiService
                  .updateTrainingStep(_currentTrainingId!, step['id'], {
                    'title': titleController.text,
                    'type': stepType,
                    'videoUrl': videoUrlController.text,
                  });
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  // ويدجت الحوار المشترك للإضافة والتعديل
  Widget _buildStepDialog({
    required String title,
    required TextEditingController titleController,
    required TextEditingController videoUrlController,
    required String stepType,
    required ValueChanged<String?> onTypeChanged,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: stepType,
            dropdownColor: const Color(0xFF2C2C2C),
            decoration: const InputDecoration(
              labelText: "نوع الخطوة",
              labelStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            items: ['checklist', 'video']
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t == 'checklist' ? 'قائمة تحقق' : 'فيديو'),
                  ),
                )
                .toList(),
            onChanged: onTypeChanged,
          ),
          TextField(
            controller: titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.stepTitle,
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
          if (stepType == 'video')
            TextField(
              controller: videoUrlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.videoUrl,
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
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
          child: Text(l10n.save, style: const TextStyle(color: Colors.black)),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        title: Text(
          _isEditing ? l10n.editTraining : l10n.addNewTraining,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentTrainingId != null)
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.white),
              onPressed: () {
                if (mounted)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrainingDetailsScreen(
                        training:
                            widget.training ??
                            {
                              'id': _currentTrainingId,
                              'title': _titleController.text,
                              'description': _descriptionController.text,
                            },
                        imageUrl: _imageUrl ?? '',
                      ),
                    ),
                  );
              },
            ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveTraining,
          ),
        ],
      ),

      floatingActionButton: _currentTrainingId != null
          ? FloatingActionButton.extended(
              onPressed: _showAddStepDialog,
              label: Text(
                l10n.addStep,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.black),
              backgroundColor: _primaryColor,
            )
          : null,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. صورة التدريب (Header)
            FadeInDown(
              duration: const Duration(milliseconds: 800),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      image: (_imageUrl != null && _imageUrl!.isNotEmpty)
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(_imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (_imageUrl == null || _imageUrl!.isEmpty)
                        ? Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 60,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          )
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),

                  // زر التعديل العائم
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. بيانات التدريب (Form)
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              delay: const Duration(milliseconds: 200),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputCard(
                      icon: Icons.title,
                      label: l10n.title,
                      child: TextFormField(
                        controller: _titleController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.enterTitle,
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      icon: Icons.description_outlined,
                      label: l10n.description,
                      child: TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.enterDescription,
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInputCard(
                      icon: Icons.layers_outlined,
                      label: l10n.level,
                      child: TextFormField(
                        controller: _levelController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.enterLevel,
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_currentTrainingId != null) ...[
              const SizedBox(height: 40),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Icon(Icons.format_list_bulleted, color: _primaryColor),
                    const SizedBox(width: 10),
                    Text(
                      l10n.manageSteps,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. قائمة الخطوات
              StreamBuilder<List<dynamic>>(
                stream: _apiService.streamSteps(_currentTrainingId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  final steps = snapshot.data ?? [];

                  if (steps.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(30),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _cardColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white10,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_task,
                            size: 40,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.noStepsYet,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: steps.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      return FadeInLeft(
                        delay: Duration(milliseconds: index * 100),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: step['type'] == 'video'
                                    ? Colors.red
                                    : Colors.green,
                                width: 4,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  (step['type'] == 'video'
                                          ? Colors.red
                                          : Colors.green)
                                      .withOpacity(0.1),
                              child: Icon(
                                step['type'] == 'video'
                                    ? Icons.videocam
                                    : Icons.check_box,
                                color: step['type'] == 'video'
                                    ? Colors.red
                                    : Colors.green,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              step['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: step['type'] == 'video'
                                ? Text(
                                    step['videoUrl'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _apiService.deleteTrainingStep(
                                _currentTrainingId!,
                                step['id'],
                              ),
                            ),
                            onTap: () => _showEditStepDialog(step),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 80), // مسافة للزر العائم
            ],
          ],
        ),
      ),
    );
  }

  // ودجت الإدخال المساعد (نفس الموجود في البروفايل لتوحيد الهوية)
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 26.0, bottom: 4),
            child: child,
          ),
        ],
      ),
    );
  }
}
