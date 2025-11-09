import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة إدارة الصلاحيات والأدوار
class RoleService {
  static const String ROLE_OWNER = 'owner';
  static const String ROLE_ADMIN = 'admin';
  static const String ROLE_MANAGER = 'manager';
  static const String ROLE_TRAINER = 'trainer';
  static const String ROLE_TRAINEE = 'trainee';
  static const String ROLE_GUEST = 'guest';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// التحقق من أن المستخدم الحالي هو Owner
  Future<bool> isOwner() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final role = userDoc.data()?['role'] as String?;
      return role == ROLE_OWNER;
    } catch (e) {
      print('Error checking owner status: $e');
      return false;
    }
  }

  /// التحقق من أن المستخدم الحالي هو Owner أو Admin
  Future<bool> isOwnerOrAdmin() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final role = userDoc.data()?['role'] as String?;
      return role == ROLE_OWNER || role == ROLE_ADMIN;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// الحصول على دور المستخدم الحالي
  Future<String?> getCurrentUserRole() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return null;

      return userDoc.data()?['role'] as String?;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Stream للحصول على دور المستخدم في الوقت الفعلي
  Stream<String?> getCurrentUserRoleStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(currentUser.uid).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      return doc.data()?['role'] as String?;
    });
  }

  /// التحقق من صلاحية معينة
  Future<bool> hasPermission(Permission permission) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;

    switch (permission) {
      // صلاحيات حصرية للـ Owner فقط
      case Permission.EXPORT_BACKUP:
      case Permission.BAN_USERS:
      case Permission.MANAGE_APP_VERSION:
      case Permission.TOGGLE_APP_STATUS:
      case Permission.COMPREHENSIVE_REPORT:
        return role == ROLE_OWNER;

      // صلاحيات للـ Owner و Admin
      case Permission.MANAGE_USERS:
      case Permission.MANAGE_TRAININGS:
      case Permission.MANAGE_COMPETITIONS:
      case Permission.VIEW_REPORTS:
        return role == ROLE_OWNER || role == ROLE_ADMIN;

      // صلاحيات للمدربين
      case Permission.ADD_TRAINING_RESULTS:
      case Permission.VIEW_TRAINEES:
        return role == ROLE_OWNER || role == ROLE_ADMIN || role == ROLE_TRAINER;
    }
  }

  /// الحصول على اسم الدور المترجم
  String getRoleDisplayName(String role) {
    switch (role) {
      case ROLE_OWNER:
        return 'المالك';
      case ROLE_ADMIN:
        return 'مدير';
      case ROLE_MANAGER:
        return 'مشرف';
      case ROLE_TRAINER:
        return 'مدرب';
      case ROLE_TRAINEE:
        return 'متدرب';
      case ROLE_GUEST:
        return 'زائر';
      default:
        return role;
    }
  }

  /// الحصول على لون الدور
  static int getRoleColor(String role) {
    switch (role) {
      case ROLE_OWNER:
        return 0xFF9C27B0; // Purple
      case ROLE_ADMIN:
        return 0xFFF44336; // Red
      case ROLE_MANAGER:
        return 0xFFFF9800; // Orange
      case ROLE_TRAINER:
        return 0xFF2196F3; // Blue
      case ROLE_TRAINEE:
        return 0xFF4CAF50; // Green
      case ROLE_GUEST:
        return 0xFF9E9E9E; // Grey
      default:
        return 0xFF607D8B; // Blue Grey
    }
  }
}

/// تعريف الصلاحيات
enum Permission {
  // صلاحيات Owner فقط
  EXPORT_BACKUP,
  BAN_USERS,
  MANAGE_APP_VERSION,
  TOGGLE_APP_STATUS,
  COMPREHENSIVE_REPORT,

  // صلاحيات Owner و Admin
  MANAGE_USERS,
  MANAGE_TRAININGS,
  MANAGE_COMPETITIONS,
  VIEW_REPORTS,

  // صلاحيات المدربين
  ADD_TRAINING_RESULTS,
  VIEW_TRAINEES,
}
