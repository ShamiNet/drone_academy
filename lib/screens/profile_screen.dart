import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cropperx/cropperx.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart'; // استيراد الخدمة
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
  final ApiService _apiService = ApiService(); // الخدمة الجديدة
  final _nameController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late AppLocalizations l10n;
  String? _photoUrl;
  bool _isLoading = true;
  bool _isUploading = false;
  final _cropKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      // استخدام ApiService لجلب البيانات
      final userData = await _apiService.fetchUser(_currentUser!.uid);

      if (mounted) {
        setState(() {
          // إذا لم نجد بيانات، نستخدم بيانات المستخدم الافتراضية
          _nameController.text =
              userData?['displayName'] ?? _currentUser!.displayName ?? '';
          _photoUrl = userData?['photoUrl'] ?? _currentUser!.photoURL;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    l10n = AppLocalizations.of(context)!;
    if (_currentUser == null) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();

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
        final String fileName =
            'profile_pic_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';

        final CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            croppedBytes,
            identifier: fileName,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        final photoUrl = response.secureUrl;

        // تحديث عبر ApiService
        await _apiService.updateUser({
          'uid': _currentUser!.uid,
          'photoUrl': photoUrl,
        });

        // تحديث البروفايل المحلي في Firebase Auth (للتوافق)
        await _currentUser!.updatePhotoURL(photoUrl);

        if (mounted) {
          setState(() => _photoUrl = photoUrl);
        }
      } catch (e) {
        print('Failed to upload image: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isNotEmpty) {
      // تحديث عبر ApiService
      await _apiService.updateUser({
        'uid': _currentUser!.uid,
        'displayName': _nameController.text,
      });

      // تحديث محلي
      await _currentUser!.updateDisplayName(_nameController.text);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    l10n = AppLocalizations.of(context)!; // تأكد من تهيئة l10n
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            (_photoUrl != null && _photoUrl!.isNotEmpty)
                            ? CachedNetworkImageProvider(_photoUrl!)
                            : null,
                        child: (_photoUrl == null || _photoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: _pickAndUploadImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.fullName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: DropdownButtonFormField<Locale>(
                      decoration: InputDecoration(
                        labelText: l10n.language,
                        prefixIcon: const Icon(Icons.language),
                        border: const OutlineInputBorder(),
                      ),
                      value: Localizations.localeOf(context),
                      onChanged: (locale) {
                        if (locale != null) widget.setLocale(locale);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: Locale('en'),
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: Locale('ar'),
                          child: Text('العربية'),
                        ),
                        DropdownMenuItem(
                          value: Locale('ru'),
                          child: Text('Русский'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(l10n.saveChanges),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.logout),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
