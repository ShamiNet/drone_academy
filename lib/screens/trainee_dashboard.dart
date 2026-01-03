import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/widgets/empty_state_widget.dart';
import 'package:drone_academy/widgets/training_card.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class TraineeDashboard extends StatefulWidget {
  const TraineeDashboard({super.key});
  @override
  State<TraineeDashboard> createState() => _TraineeDashboardState();
}

class _TraineeDashboardState extends State<TraineeDashboard> {
  final ApiService _apiService = ApiService();

  // متغير لحفظ المستوى الحالي (الافتراضي 1)
  int _userLevel = 1;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  Future<void> _refreshUserData() async {
    try {
      final currentUid =
          ApiService.currentUser?['uid'] ?? ApiService.currentUser?['id'];
      if (currentUid != null) {
        final userData = await _apiService.fetchUser(currentUid);
        if (userData != null && mounted) {
          setState(() {
            _userLevel = int.tryParse(userData['level'].toString()) ?? 1;
            ApiService.currentUser = userData;
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bgColor = Color(0xFF111318);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        // تغيير العنوان ليعكس أنه يعرض كل التدريبات حتى المستوى الحالي
        title: _isLoadingUser
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                "التدريبات المتاحة (حتى مستوى $_userLevel)",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoadingUser = true);
              _refreshUserData();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: _apiService.streamTrainings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isLoadingUser) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade800,
              highlightColor: Colors.grey.shade700,
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    height: 70.0,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            );
          }

          final allTrainings = snapshot.data ?? [];

          // 🔥 التعديل هنا: استخدام (<=) بدلاً من (==)
          // هذا يعني: اعرض أي تمرين مستواه أقل من أو يساوي مستوى المتدرب
          final filteredTrainings = allTrainings.where((training) {
            final trainingLevel =
                int.tryParse(training['level'].toString()) ?? 1;
            return trainingLevel <= _userLevel;
          }).toList();

          if (filteredTrainings.isEmpty) {
            return EmptyStateWidget(
              message: l10n.noTrainingsAvailable,
              imagePath: 'assets/illustrations/no_data.svg',
            );
          }

          // تجميع التمارين حسب المستوى لعرضها مرتبة
          final Map<int, List<dynamic>> trainingsByLevel = {};
          for (var training in filteredTrainings) {
            final level = int.tryParse(training['level'].toString()) ?? 1;
            if (trainingsByLevel[level] == null) {
              trainingsByLevel[level] = [];
            }
            trainingsByLevel[level]!.add(training);
          }
          final sortedLevels = trainingsByLevel.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: sortedLevels.length,
            itemBuilder: (context, index) {
              final level = sortedLevels[index];
              final levelTrainings = trainingsByLevel[level]!;

              // جعل القائمة مفتوحة فقط لأعلى مستوى وصل له المتدرب
              // المستويات السابقة تكون مغلقة (اختياري، لترتيب الشكل)
              final bool isCurrentLevel = (level == _userLevel);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(10),
                  // تمييز بسيط للمستوى الحالي بإطار ملون
                  border: isCurrentLevel
                      ? Border.all(
                          color: const Color(0xFF3F51B5).withOpacity(0.5),
                        )
                      : null,
                ),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      '${l10n.level} $level',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        // تلوين عنوان المستوى الحالي لتمييزه
                        color: isCurrentLevel
                            ? const Color(0xFF64B5F6)
                            : Colors.white,
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isCurrentLevel
                          ? const Color(0xFF3F51B5)
                          : Colors.grey.shade700,
                      child: Text(
                        '$level',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    collapsedIconColor: Colors.grey,
                    iconColor: const Color(0xFF8FA1B4),
                    initiallyExpanded:
                        isCurrentLevel, // فتح المستوى الحالي تلقائياً
                    children: levelTrainings.map((training) {
                      return TrainingCard(training: training);
                    }).toList(),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
