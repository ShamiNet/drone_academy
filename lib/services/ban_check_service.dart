import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BanCheckService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Check if the current user is banned
  Future<bool> isUserBanned() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('🔒 No user logged in, allowing access');
        return false;
      }

      print('🔍 Checking ban status for user: ${currentUser.uid}');

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⏱️ Ban check timeout, allowing access');
              return _firestore.collection('users').doc(currentUser.uid).get();
            },
          );

      if (!userDoc.exists) {
        print('⚠️ User document does not exist, allowing access');
        return false;
      }

      final data = userDoc.data();
      final isBanned = data?['isBanned'] as bool? ?? false;

      print(isBanned ? '🚫 User is BANNED' : '✅ User is NOT banned');

      return isBanned;
    } catch (e) {
      print('❌ Error checking ban status: $e');
      // If there's an error, allow access (fail-safe)
      return false;
    }
  }

  /// Listen to real-time ban status changes
  Stream<bool> banStatusStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final data = doc.data();
          return data?['isBanned'] as bool? ?? false;
        })
        .handleError((error) {
          print('❌ Error in ban status stream: $error');
          return false;
        });
  }
}
