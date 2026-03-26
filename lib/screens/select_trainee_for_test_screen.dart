import 'package:cached_network_image/cached_network_image.dart';
import 'package:drone_academy/l10n/app_localizations.dart';
import 'package:drone_academy/screens/competition_timer_screen.dart';
import 'package:drone_academy/services/api_service.dart';
import 'package:drone_academy/utils/organization_mapping.dart';
import 'package:flutter/material.dart';

class SelectTraineeForTestScreen extends StatefulWidget {
  final Map<String, dynamic> competition;

  const SelectTraineeForTestScreen({super.key, required this.competition});

  @override
  State<SelectTraineeForTestScreen> createState() =>
      _SelectTraineeForTestScreenState();
}

class _SelectTraineeForTestScreenState
    extends State<SelectTraineeForTestScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _trainees = [];
  List<dynamic> _filteredTrainees = [];
  String _searchQuery = '';
  String _selectedLevel = 'All';
  String _selectedUnit = 'All';
  String _selectedDivision = 'All';

  // Colors for consistent styling
  final Color _bgColor = const Color(0xFF111318);
  final Color _cardColor = const Color(0xFF1E2230);
  final Color _primaryColor = const Color(0xFFFF9800);
  final Color _accentColor = const Color(0xFF3F51B5);

  String _getNormalizedDivisionLabel(Map<String, dynamic> trainee) {
    return divisionLabelFromUser(trainee);
  }

  // Helper function to get display name for unit type
  String _getUnitDisplayName(dynamic unitType) {
    final unitStr = unitType?.toString();
    switch (unitStr) {
      case 'markazia':
        return 'مركزية';
      case 'liwa':
        return 'الوية';
      default:
        return 'غير محدد';
    }
  }

  // Helper function to get color for level
  Color _getLevelColor(dynamic level) {
    final levelStr = level?.toString();
    switch (levelStr) {
      case '1':
        return Colors.green;
      case '2':
        return Colors.blue;
      case '3':
        return Colors.orange;
      case '4':
        return Colors.red;
      case '5':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Helper function to get color for unit type
  Color _getUnitColor(dynamic unitType) {
    final unitStr = unitType?.toString();
    switch (unitStr) {
      case 'markazia':
        return const Color(0xFF9C27B0); // Purple
      case 'liwa':
        return const Color(0xFF009688); // Teal
      default:
        return Colors.grey;
    }
  }

  // Helper function to get color for division
  Color _getDivisionColor(dynamic division) {
    final divisionStr = normalizeOrganizationValue(division);
    if (divisionStr.isEmpty || divisionStr == 'غير محدد') {
      return Colors.grey;
    }

    switch (divisionStr) {
      case 'اللواء الأول':
        return const Color(0xFF4CAF50); // Green
      case 'اللواء الثاني':
        return const Color(0xFF2196F3); // Blue
      case 'اللواء الثالث':
        return const Color(0xFFFF9800); // Orange
      case 'اللواء الرابع':
        return const Color(0xFFF44336); // Red
      case 'المدفعية':
        return const Color(0xFF9C27B0); // Purple
      case 'المركزية':
        return const Color(0xFF795548); // Brown
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTrainees();
  }

  Future<void> _loadTrainees() async {
    try {
      final users = await _apiService.fetchUsers();
      final trainees = users
          .where((user) => user['role'] == 'trainee')
          .toList();
      setState(() {
        _trainees = trainees;
        _filteredTrainees = trainees;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _refreshTrainees() async {
    await _loadTrainees();
  }

  void _filterTrainees() {
    setState(() {
      _filteredTrainees = _trainees.where((trainee) {
        final normalizedDivision = _getNormalizedDivisionLabel(
          trainee as Map<String, dynamic>,
        );
        final matchesSearch =
            trainee['displayName']?.toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ??
            false;
        final matchesLevel =
            _selectedLevel == 'All' ||
            trainee['level']?.toString() == _selectedLevel;
        final matchesUnit =
            _selectedUnit == 'All' ||
            trainee['unitType']?.toString() == _selectedUnit;
        final matchesDivision =
            _selectedDivision == 'All' ||
            normalizedDivision == _selectedDivision;
        return matchesSearch && matchesLevel && matchesUnit && matchesDivision;
      }).toList();

      // Sort by level
      _filteredTrainees.sort((a, b) {
        final levelA = int.tryParse(a['level']?.toString() ?? '0') ?? 0;
        final levelB = int.tryParse(b['level']?.toString() ?? '0') ?? 0;
        return levelB.compareTo(levelA); // Higher level first
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'اختيار متدرب للاختبار',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header section with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor, _bgColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_search,
                    size: 40,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "اختر المتدرب المناسب",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "استخدم الفلاتر للعثور على المتدرب المطلوب",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search and filters section
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTrainees,
              color: _primaryColor,
              backgroundColor: _cardColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'البحث بالاسم...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: _primaryColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        onChanged: (value) {
                          _searchQuery = value;
                          _filterTrainees();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filters row
                    const Text(
                      'الفلاتر',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Level filter
                    Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedLevel,
                        dropdownColor: _cardColor,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب المستوى',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'جميع المستويات',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '1',
                            child: Text(
                              'المستوى 1',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '2',
                            child: Text(
                              'المستوى 2',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '3',
                            child: Text(
                              'المستوى 3',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '4',
                            child: Text(
                              'المستوى 4',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: '5',
                            child: Text(
                              'المستوى 5',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _selectedLevel = value ?? 'All';
                          _filterTrainees();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Unit filter
                    Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        dropdownColor: _cardColor,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب الوحدة',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'جميع الوحدات',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'markazia',
                            child: Text(
                              'مركزية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'liwa',
                            child: Text(
                              'الوية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _selectedUnit = value ?? 'All';
                          _filterTrainees();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Division filter
                    Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedDivision,
                        dropdownColor: _cardColor,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'فلترة حسب اللواء',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text(
                              'جميع الالوية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'اللواء الأول',
                            child: Text(
                              'اللواء الأول',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'اللواء الثاني',
                            child: Text(
                              'اللواء الثاني',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'اللواء الثالث',
                            child: Text(
                              'اللواء الثالث',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'اللواء الرابع',
                            child: Text(
                              'اللواء الرابع',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'المدفعية',
                            child: Text(
                              'المدفعية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'المركزية',
                            child: Text(
                              'المركزية',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          _selectedDivision = value ?? 'All';
                          _filterTrainees();
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Trainees list
                    Text(
                      'المتدربون (${_filteredTrainees.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    RefreshIndicator(
                      onRefresh: _refreshTrainees,
                      color: _primaryColor,
                      backgroundColor: _cardColor,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredTrainees.length,
                        itemBuilder: (context, index) {
                          final trainee =
                              _filteredTrainees[index] as Map<String, dynamic>;
                          final divisionLabel = _getNormalizedDivisionLabel(
                            trainee,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: _accentColor.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _primaryColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      trainee['photoUrl'] != null &&
                                          trainee['photoUrl']
                                              .toString()
                                              .isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: trainee['photoUrl'],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: _cardColor,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                color: _cardColor,
                                                child: Center(
                                                  child: Text(
                                                    trainee['displayName']?[0]
                                                            ?.toUpperCase() ??
                                                        '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 20,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        )
                                      : Container(
                                          color: _cardColor,
                                          child: Center(
                                            child: Text(
                                              trainee['displayName']?[0]
                                                      ?.toUpperCase() ??
                                                  '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trainee['displayName'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (trainee['nickname'] != null &&
                                      trainee['nickname']
                                          .toString()
                                          .trim()
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        trainee['nickname'],
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'المستوى: ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '${trainee['level'] ?? 'غير محدد'}',
                                        style: TextStyle(
                                          color: _getLevelColor(
                                            trainee['level'],
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' | الوحدة: ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextSpan(
                                        text: _getUnitDisplayName(
                                          trainee['unitType'],
                                        ),
                                        style: TextStyle(
                                          color: _getUnitColor(
                                            trainee['unitType'],
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' | الالوية: ',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextSpan(
                                        text: divisionLabel.isNotEmpty
                                            ? divisionLabel
                                            : 'غير محدد',
                                        style: TextStyle(
                                          color: _getDivisionColor(
                                            divisionLabel,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                color: _primaryColor,
                                size: 20,
                              ),
                              onTap: () {
                                final traineeDoc = {
                                  'id': trainee['uid'] ?? trainee['id'],
                                  'displayName':
                                      trainee['displayName'] ?? 'Unknown',
                                };
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CompetitionTimerScreen(
                                          competition: widget.competition,
                                          traineeDoc: traineeDoc,
                                        ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
