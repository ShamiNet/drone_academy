import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cropperx/cropperx.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/language_selector.dart';
import 'package:drone_academy/widgets/loading_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  const ProfileScreen({super.key, required this.setLocale});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();

  // --- المتحكمات ---
  final _nameController = TextEditingController();
  final _militaryNumController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _attributeController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _countryController = TextEditingController();
  final _jobController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _phoneSyriaController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();
  final _recommendationController = TextEditingController();

  // --- الحقول الجديدة (Dropdowns) ---
  String? _selectedMaritalStatus;
  String? _selectedUnitType;

  Map<String, dynamic>? _user;
  String? _photoUrl;
  bool _isLoading = true;
  bool _isUploading = false;
  final _cropKey = GlobalKey();

  // الألوان
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _user = ApiService.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user != null) {
      final uid = _user!['uid'] ?? _user!['id'];
      final userData = await _apiService.fetchUser(uid);

      if (mounted) {
        setState(() {
          final data = userData ?? _user!;
          _user = data;
          _photoUrl = data['photoUrl'];

          _nameController.text = data['displayName'] ?? '';
          _militaryNumController.text = data['militaryNumber'] ?? '';
          _nicknameController.text = data['nickname'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _attributeController.text = data['attribute'] ?? '';
          _ageController.text = data['age'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _countryController.text = data['country'] ?? '';
          _jobController.text = data['job'] ?? '';
          _groupNameController.text = data['groupName'] ?? '';
          _phoneSyriaController.text = data['phoneSyria'] ?? '';
          _whatsappController.text = data['whatsapp'] ?? '';
          _telegramController.text = data['telegram'] ?? '';
          _recommendationController.text = data['recommendation'] ?? '';

          // [تصحيح الخطأ هنا] ✅
          // التحقق من القيم القادمة من السيرفر: إذا كانت نصاً فارغاً، نحولها لـ null
          // لكي لا ينهار الـ DropdownButton

          String? ms = data['maritalStatus'];
          if (ms != null &&
              (ms.isEmpty || !['single', 'married'].contains(ms))) {
            ms = null;
          }
          _selectedMaritalStatus = ms;

          String? ut = data['unitType'];
          if (ut != null &&
              (ut.isEmpty || !['liwa', 'markazia'].contains(ut))) {
            ut = null;
          }
          _selectedUnitType = ut;

          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final l10n = AppLocalizations.of(context)!;
    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;
    final imageBytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    // شاشة القص
    final Uint8List? croppedBytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              l10n.cropImage,
              style: const TextStyle(color: Colors.white),
            ),
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
              overlayType: OverlayType.circle,
              aspectRatio: 1.0,
            ),
          ),
        ),
      ),
    );

    if (croppedBytes != null) {
      setState(() => _isUploading = true);
      final cloudinary = CloudinaryPublic('dvocrpapc', 'ml_default');
      try {
        final uid = _user!['uid'] ?? _user!['id'];
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            croppedBytes,
            identifier: 'p_$uid',
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        final url = response.secureUrl;
        await _apiService.updateUser({'uid': uid, 'photoUrl': url});
        if (ApiService.currentUser != null)
          ApiService.currentUser!['photoUrl'] = url;
        setState(() {
          _photoUrl = url;
          _isUploading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.profilePictureUpdated)));
        }
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("${l10n.failed}: $e")));
        }
      }
    }
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (_user != null) {
      final uid = _user!['uid'] ?? _user!['id'];

      final updatedData = {
        'uid': uid,
        'displayName': _nameController.text,
        'militaryNumber': _militaryNumController.text,
        'nickname': _nicknameController.text,
        'specialization': _specializationController.text,
        'attribute': _attributeController.text,
        'age': _ageController.text,
        'bio': _bioController.text,
        'country': _countryController.text,
        'job': _jobController.text,
        'groupName': _groupNameController.text,
        'phoneSyria': _phoneSyriaController.text,
        'whatsapp': _whatsappController.text,
        'telegram': _telegramController.text,
        'recommendation': _recommendationController.text,
        'maritalStatus': _selectedMaritalStatus ?? '',
        'unitType': _selectedUnitType ?? '',
      };

      await _apiService.updateUser(updatedData);

      if (ApiService.currentUser != null) {
        ApiService.currentUser!.addAll(updatedData);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.saveChanges)));
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;

    await _apiService.logout();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return LoadingView(message: l10n.loading);
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: Text(
          l10n.editProfile,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- الصورة ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: _cardColor,
                    backgroundImage:
                        (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(_photoUrl!)
                        : null,
                    child: (_photoUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(child: CircularProgressIndicator()),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: CircleAvatar(
                        backgroundColor: _primaryColor,
                        radius: 18,
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // اختيار اللغة
            const LanguageSelector(showTitle: true, isCompact: false),
            const SizedBox(height: 30),

            _buildSectionTitle("المعلومات الأساسية"),
            _buildTextField(
              icon: Icons.person,
              label: l10n.fullName,
              controller: _nameController,
            ),
            _buildTextField(
              icon: Icons.badge,
              label: "الرقم العسكري",
              controller: _militaryNumController,
            ),

            // --- اختيار نوع الوحدة ---
            _buildDropdownField(
              icon: Icons.flag,
              label: l10n.unitType,
              value: _selectedUnitType,
              items: [
                DropdownMenuItem(value: 'liwa', child: Text(l10n.liwa)),
                DropdownMenuItem(value: 'markazia', child: Text(l10n.markazia)),
              ],
              onChanged: (val) => setState(() => _selectedUnitType = val),
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("المعلومات المهنية"),
            _buildTextField(
              icon: Icons.work,
              label: "الاختصاص",
              controller: _specializationController,
            ),
            _buildTextField(
              icon: Icons.label,
              label: "الصفة",
              controller: _attributeController,
            ),
            _buildTextField(
              icon: Icons.work_outline,
              label: "العمل",
              controller: _jobController,
            ),
            _buildTextField(
              icon: Icons.group,
              label: "اسم المجموعة",
              controller: _groupNameController,
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("معلومات شخصية"),
            _buildTextField(
              icon: Icons.cake,
              label: "العمر",
              controller: _ageController,
              isNumber: true,
            ),

            // --- اختيار الحالة الاجتماعية ---
            _buildDropdownField(
              icon: Icons.family_restroom,
              label: "الحالة الاجتماعية",
              value: _selectedMaritalStatus,
              items: const [
                DropdownMenuItem(value: 'single', child: Text('أعزب')),
                DropdownMenuItem(value: 'married', child: Text('متزوج')),
              ],
              onChanged: (val) => setState(() => _selectedMaritalStatus = val),
            ),

            _buildTextField(
              icon: Icons.public,
              label: "البلد",
              controller: _countryController,
            ),
            _buildTextField(
              icon: Icons.info_outline,
              label: "النبذة (Bio)",
              controller: _bioController,
              maxLines: 3,
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("التواصل"),
            _buildTextField(
              icon: Icons.phone,
              label: "الرقم السوري",
              controller: _phoneSyriaController,
              isNumber: true,
            ),
            _buildTextField(
              icon: Icons.chat,
              label: "الواتس اب",
              controller: _whatsappController,
              isNumber: true,
            ),
            _buildTextField(
              icon: Icons.send,
              label: "التلغرام",
              controller: _telegramController,
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("إضافي"),
            _buildTextField(
              icon: Icons.recommend,
              label: "التزكية",
              controller: _recommendationController,
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.saveChanges,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text(
                l10n.logout,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required IconData icon,
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: _cardColor,
                style: const TextStyle(color: Colors.white),
                hint: Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
