import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cropperx/cropperx.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditEquipmentScreen extends StatefulWidget {
  final Map<String, dynamic>? equipment;
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

  // ألوان التصميم
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

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
            title: const Text('قص الصورة'),
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
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _flightHoursController.dispose();
    _chargeCyclesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? l10n.editEquipment : l10n.addEquipment,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.green),
            onPressed: _saveEquipment,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. صورة المعدة
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
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
                                fit: BoxFit.contain,
                              )
                            : null,
                      ),
                      child: (_imageUrl == null || _imageUrl!.isEmpty)
                          ? Center(
                              child: Icon(
                                Icons.precision_manufacturing_outlined,
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

              // 2. البيانات الأساسية
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: _buildInputCard(
                  icon: Icons.label,
                  label: l10n.equipmentName,
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "مثال: طائرة مافيك 3",
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                    ),
                    validator: (v) => v!.isEmpty ? 'هذا الحقل مطلوب' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // النوع والحالة
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInputCard(
                        icon: Icons.category,
                        label: l10n.equipmentType,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            dropdownColor: const Color(0xFF2C2C2C),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                            isExpanded: true,
                            items: ['drone', 'battery', 'controller', 'other']
                                .map((t) {
                                  String label = t;
                                  if (t == 'drone') label = 'طائرة درون';
                                  if (t == 'battery') label = 'بطارية';
                                  if (t == 'controller') label = 'وحدة تحكم';
                                  if (t == 'other') label = 'أخرى';
                                  return DropdownMenuItem(
                                    value: t,
                                    child: Text(label),
                                  );
                                })
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedType = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputCard(
                        icon: Icons.info_outline,
                        label: l10n.status,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            dropdownColor: const Color(0xFF2C2C2C),
                            style: TextStyle(
                              color: _getStatusColor(_selectedStatus),
                              fontWeight: FontWeight.bold,
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                            isExpanded: true,
                            items: ['available', 'inUse', 'inMaintenance'].map((
                              s,
                            ) {
                              String label = s;
                              if (s == 'available') label = 'متاح';
                              if (s == 'inUse') label = 'قيد الاستخدام';
                              if (s == 'inMaintenance') label = 'في الصيانة';
                              return DropdownMenuItem(
                                value: s,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedStatus = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // حقول ديناميكية
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    if (_selectedType == 'drone')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FadeInUp(
                          child: _buildInputCard(
                            icon: Icons.access_time,
                            label: l10n.totalFlightHours,
                            child: TextFormField(
                              controller: _flightHoursController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "0",
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_selectedType == 'battery')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FadeInUp(
                          child: _buildInputCard(
                            icon: Icons.battery_charging_full,
                            label: l10n.totalChargeCycles,
                            child: TextFormField(
                              controller: _chargeCyclesController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "0",
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // الملاحظات
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildInputCard(
                  icon: Icons.note,
                  label: l10n.notes,
                  child: TextFormField(
                    controller: _notesController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "أي ملاحظات إضافية حول الحالة...",
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // زر الحفظ
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _saveEquipment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    icon: const Icon(Icons.save_outlined, color: Colors.black),
                    label: Text(
                      l10n.save,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.greenAccent;
      case 'inUse':
        return Colors.orangeAccent;
      case 'inMaintenance':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }

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
            offset: const Offset(0, 4),
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
