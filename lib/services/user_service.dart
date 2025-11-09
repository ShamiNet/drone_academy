import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drone_academy/models/user_model.dart';

class UserService {
  final _db = FirebaseFirestore.instance;

  Stream<List<UserModel>> get allUsersStream {
    return _db
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((d) => UserModel.fromDoc(d)).toList(),
        );
  }

  Future<void> updateUserBanStatus(String uid, bool isBanned) async {
    await _db.collection('users').doc(uid).update({'isBanned': isBanned});
  }
}
