// lib/screens/edit_equipment_screen.dart

import 'dart:io';
import 'dart:typed_data'; // مطلوب للتعامل مع بيانات الصورة
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cropperx/cropperx.dart'; // استيراد حزمة قص الصور

class EditEquipmentScreen extends StatefulWidget {
  final DocumentSnapshot? equipment;
  const EditEquipmentScreen({super.key, this.equipment});

  @override
  State<EditEquipmentScreen> createState() => _EditEquipmentScreenState();
}

class _EditEquipmentScreenState extends State<EditEquipmentScreen> {
  late AppLocalizations l10n;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _flightHoursController = TextEditingController();
  final _chargeCyclesController = TextEditingController();

  String _selectedType = 'drone';
  String _selectedStatus = 'available';
  String? _imageUrl;
  bool _isUploading = false;
  bool get _isEditing => widget.equipment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      // قراءة آمنة للبيانات
      final data = widget.equipment!.data() as Map<String, dynamic>;
      _nameController.text = data['name'];
      _notesController.text = data.containsKey('notes') ? data['notes'] : '';
      _flightHoursController.text =
          (data.containsKey('totalFlightHours') ? data['totalFlightHours'] : 0)
              .toString();
      _chargeCyclesController.text =
          (data.containsKey('totalChargeCycles')
                  ? data['totalChargeCycles']
                  : 0)
              .toString();
      _selectedType = data['type'];
      _selectedStatus = data['status'];
      if (data.containsKey('imageUrl')) {
        _imageUrl = data['imageUrl'];
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
    _nameController.dispose();
    _notesController.dispose();
    _flightHoursController.dispose();
    _chargeCyclesController.dispose();
    super.dispose();
  }

  // --- دالة اختيار وقص الصورة ---
  Future<void> _pickAndUploadImage() async {
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();
    final cropKey = GlobalKey(); // استخدام GlobalKey بدون نوع

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
                  final cropped = await Cropper.crop(cropperKey: cropKey);
                  Navigator.pop(context, cropped);
                },
              ),
            ],
          ),
          body: Center(
            child: Cropper(
              cropperKey: cropKey,
              image: Image.memory(imageBytes),
              aspectRatio: 1.0, // قص مربع 1:1 مناسب للمعدات
              overlayType: OverlayType.rectangle, // عرض شبكة مربعة
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
            'equipment_image_${DateTime.now().millisecondsSinceEpoch}';

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

  // --- دالة حفظ المعدات ---
  Future<void> _saveEquipment() async {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameController.text,
        'type': _selectedType,
        'status': _selectedStatus,
        'imageUrl': _imageUrl ?? '',
        'notes': _notesController.text,
        'totalFlightHours': int.tryParse(_flightHoursController.text) ?? 0,
        'totalChargeCycles': int.tryParse(_chargeCyclesController.text) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('equipment')
            .doc(widget.equipment!.id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('equipment').add(data);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editEquipment : l10n.addEquipment),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveEquipment),
        ],
      ),
      // استخدام ListView للسماح بالتمرير
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- قسم عرض ورفع الصورة ---
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: CachedNetworkImage(
                          imageUrl: _imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
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
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.equipmentName),
                  validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: InputDecoration(labelText: l10n.equipmentType),
                  items: [
                    DropdownMenuItem(value: 'drone', child: Text(l10n.drone)),
                    DropdownMenuItem(
                      value: 'battery',
                      child: Text(l10n.battery),
                    ),
                    DropdownMenuItem(
                      value: 'controller',
                      child: Text(l10n.controller),
                    ),
                    DropdownMenuItem(value: 'other', child: Text(l10n.other)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(labelText: l10n.status),
                  items: [
                    DropdownMenuItem(
                      value: 'available',
                      child: Text(l10n.available),
                    ),
                    DropdownMenuItem(value: 'inUse', child: Text(l10n.inUse)),
                    DropdownMenuItem(
                      value: 'inMaintenance',
                      child: Text(l10n.inMaintenance),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStatus = value);
                  },
                ),
                const SizedBox(height: 16),
                // إظهار الحقول بشكل مشروط
                if (_selectedType == 'drone')
                  TextFormField(
                    controller: _flightHoursController,
                    decoration: InputDecoration(
                      labelText: l10n.totalFlightHours,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                if (_selectedType == 'battery')
                  TextFormField(
                    controller: _chargeCyclesController,
                    decoration: InputDecoration(
                      labelText: l10n.totalChargeCycles,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(labelText: l10n.notes),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
