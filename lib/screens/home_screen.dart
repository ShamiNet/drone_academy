import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/admin_dashboard.dart';
import 'package:drone_academy/screens/inventory_screen.dart';
import 'package:drone_academy/screens/my_progress_screen.dart';
import 'package:drone_academy/screens/profile_screen.dart';
import 'package:drone_academy/screens/trainee_competitions_screen.dart';
import 'package:drone_academy/screens/trainee_dashboard.dart';
import 'package:drone_academy/screens/trainer_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/screens/equipment_checkout_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Locale) setLocale;
  const HomeScreen({super.key, required this.setLocale});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ignore: unused_field
  String? _userName;
  String? _userRole;
  String? _photoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted && docSnapshot.exists) {
          setState(() {
            _userName = docSnapshot.data()?['displayName'];
            _userRole = docSnapshot.data()?['role'];
            _photoUrl = docSnapshot.data()?['photoUrl'];
            _isLoading = false;
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_userRole == 'trainer') {
      // --- تم الإصلاح هنا: تمرير دالة setLocale ---
      return TrainerDashboard(onLocaleChange: widget.setLocale);
    } else if (_userRole == 'trainee') {
      return DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(
                  text: l10n.trainings,
                  icon: const Icon(Icons.model_training),
                ),
                Tab(
                  text: l10n.competitions,
                  icon: const Icon(Icons.emoji_events),
                ), // --- 3. إضافة التبويب الجديد ---
                Tab(text: l10n.equipment, icon: const Icon(Icons.construction)),
                Tab(text: l10n.inventory, icon: const Icon(Icons.all_inbox)),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  TraineeDashboard(),
                  TraineeCompetitionsScreen(), // --- 4. إضافة الواجهة الجديدة ---
                  EquipmentCheckoutScreen(),
                  InventoryScreen(),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_userRole == 'admin') {
      return const AdminDashboard();
    } else {
      return Center(
        child: Text(l10n.welcome, style: const TextStyle(fontSize: 24)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? l10n.loading : l10n.home),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(setLocale: widget.setLocale),
                  ),
                ).then((_) => _fetchUserData());
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    (_photoUrl != null &&
                        _photoUrl!.isNotEmpty) // --- التعديل هنا
                    ? CachedNetworkImageProvider(_photoUrl!)
                    : null,
                child: (_photoUrl == null || _photoUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          if (_userRole == 'trainee')
            IconButton(
              tooltip: l10n.myProgress,
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyProgressScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(l10n),
    );
  }
}
