import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// 1. استيراد حزمة Cloudinary
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:typed_data'; // مطلوب للتعامل مع بيانات الصورة
import 'package:cropperx/cropperx.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  const ProfileScreen({super.key, required this.setLocale});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;
  late AppLocalizations l10n;
  String? _photoUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();
      setState(() {
        _nameController.text = userDoc.data()?['displayName'] ?? '';
        _photoUrl = userDoc.data()?['photoUrl'];
        _isLoading = false;
      });
    }
  }

  // --- ٢. تعديل دالة رفع الصورة لتستخدم CropperX ---
  Future<void> _pickAndUploadImage() async {
    l10n = AppLocalizations.of(context)!;
    // افتراض أن 'currentUser' مُعرّف في الكلاس
    if (_currentUser == null) return;

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    final imageBytes = await pickedFile.readAsBytes();

    // --- بداية التعديل: تعريف المفتاح هنا ---
    final cropKey = GlobalKey();
    // --- نهاية التعديل ---

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
                  // --- بداية التعديل: استخدام 'await' ---
                  final cropped = await Cropper.crop(cropperKey: cropKey);
                  // --- نهاية التعديل ---
                  Navigator.pop(context, cropped);
                },
              ),
            ],
          ),
          body: Center(
            child: Cropper(
              cropperKey: cropKey,
              image: Image.memory(imageBytes),
              // --- ٣. تعديل القص ليناسب الصورة الشخصية (دائري) ---
              overlayType: OverlayType.circle,
              aspectRatio: 1.0, // مربع (ضروري للدائرة)
              // --- نهاية التعديل ---
            ),
          ),
        ),
      ),
    );

    if (croppedBytes != null) {
      setState(() => _isUploading = true);

      final cloudinary = CloudinaryPublic('dvocrpapc', 'ml_default');

      try {
        // --- بداية التعديل: استخدام 'currentUser' بدلاً من '_currentUser' ---
        final String fileName =
            'profile_pic_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}';
        // --- نهاية التعديل ---

        final CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
            croppedBytes,
            identifier: fileName,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        final photoUrl = response.secureUrl;

        // تحديث رابط الصورة في Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'photoUrl': photoUrl});

        // تحديث رابط الصورة في ملف مصادقة Firebase
        await _currentUser!.updatePhotoURL(photoUrl);
      } catch (e) {
        print('Failed to upload image: $e');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'displayName': _nameController.text});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
      Navigator.of(context).pop();
    }
  }

  // --- دالة جديدة لتسجيل الخروج ---
  Future<void> _logout() async {
    // التأكد من أن الـ context ما زال صالحاً قبل استخدامه
    if (!mounted) return;

    // تسجيل الخروج من Firebase
    await FirebaseAuth.instance.signOut();

    // العودة إلى شاشة تسجيل الدخول وإزالة كل الشاشات السابقة
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/', // العودة إلى المسار الرئيسي الذي يعرض شاشة الدخول
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // ... باقي الكود يبقى كما هو ...
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
                            _photoUrl != null &&
                                _photoUrl!
                                    .isNotEmpty // --- التعديل هنا
                            ? CachedNetworkImageProvider(_photoUrl!)
                            : null,
                        child: _photoUrl == null || _photoUrl!.isEmpty
                            ? const Icon(Icons.person, size: 60)
                            : null,
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
                  // --- بداية الكود المنقول ---
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
                  // --- نهاية الكود المنقول ---
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(l10n.saveChanges),
                  ),
                  const SizedBox(height: 16),
                  // --- بداية الكود المنقول (زر تسجيل الخروج) ---
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
                  // --- نهاية الكود المنقول ---
                ],
              ),
            ),
    );
  }
}
