import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cropperx/cropperx.dart';

class EditEquipmentScreen extends StatefulWidget {
  final Map<String, dynamic>? equipment; // تغيير إلى Map
  const EditEquipmentScreen({super.key, this.equipment});

  @override
  State<EditEquipmentScreen> createState() => _EditEquipmentScreenState();
}

class _EditEquipmentScreenState extends State<EditEquipmentScreen> {
  final ApiService _apiService = ApiService();
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
  final _cropKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.equipment!;
      _nameController.text = data['name'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _flightHoursController.text = (data['totalFlightHours'] ?? 0).toString();
      _chargeCyclesController.text = (data['totalChargeCycles'] ?? 0)
          .toString();
      _selectedType = data['type'] ?? 'drone';
      _selectedStatus = data['status'] ?? 'available';
      _imageUrl = data['imageUrl'];
    }
  }

  // ... (دالة _pickAndUploadImage تبقى كما هي، لا تعتمد على DB) ...
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
            title: Text('Crop'),
            actions: [
              IconButton(
                icon: const Icon(Icons.check),
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
              aspectRatio: 1.0,
              overlayType: OverlayType.rectangle,
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
            identifier: 'eq_${DateTime.now().millisecondsSinceEpoch}',
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
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        await _apiService.updateEquipment(widget.equipment!['id'], data);
      } else {
        data['createdAt'] = DateTime.now().toIso8601String();
        await _apiService.addEquipment(data);
      }
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    // ... (نفس كود الواجهة السابق بالضبط، فقط تأكد من استخدام المتغيرات أعلاه)
    // سأضع الهيكل الأساسي للتأكيد
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editEquipment : l10n.addEquipment),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveEquipment),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // صورة
          Stack(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[200],
                child: _imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image, size: 50),
              ),
              if (_isUploading)
                const Center(child: CircularProgressIndicator()),
              if (!_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _pickAndUploadImage,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.equipmentName),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _selectedType,
                  items: ['drone', 'battery', 'controller', 'other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _selectedStatus,
                  items: ['available', 'inUse', 'inMaintenance']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(labelText: l10n.notes),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
