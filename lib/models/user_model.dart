import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String role;
  final bool isBanned;

  UserModel({
    required this.uid,
    this.name,
    this.email,
    this.photoUrl,
    String? role,
    bool? isBanned,
  }) : role = role ?? 'guest',
       isBanned = isBanned ?? false;

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return UserModel(
      uid: doc.id,
      name: data['displayName'] as String? ?? data['name'] as String?,
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: (data['role'] as String?) ?? 'guest',
      isBanned: (data['isBanned'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    if (name != null) 'name': name,
    if (email != null) 'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'role': role,
    'isBanned': isBanned,
  };
}
