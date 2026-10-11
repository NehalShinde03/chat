import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.avatarUrl,
    super.phoneNumber,
    super.statusMessage,
    super.isOnline = false,
    super.lastSeen,
  });

  factory UserModel.fromFirebaseUser(fb.User user) {
    return UserModel(
      id: user.uid,
      name: user.displayName ??
          (user.email != null && user.email!.contains('@')
              ? user.email!.split('@').first
              : 'WhatsApp User'),
      email: user.email ?? '',
      avatarUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
      statusMessage: 'Hey there! I am using WhatsApp.',
      isOnline: true,
      lastSeen: DateTime.now(),
    );
  }

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime? lastSeen;
    final rawLastSeen = data['lastSeen'];
    if (rawLastSeen != null) {
      if (rawLastSeen is Timestamp) {
        lastSeen = rawLastSeen.toDate();
      } else if (rawLastSeen is DateTime) {
        lastSeen = rawLastSeen;
      } else if (rawLastSeen is String) {
        lastSeen = DateTime.tryParse(rawLastSeen);
      }
    }

    return UserModel(
      id: id,
      name: (data['displayName'] ?? data['name'] ?? 'WhatsApp User') as String,
      email: (data['email'] ?? '') as String,
      avatarUrl: (data['photoURL'] ?? data['avatarUrl']) as String?,
      phoneNumber: data['phoneNumber'] as String?,
      statusMessage: (data['statusMessage'] ?? 'Hey there! I am using WhatsApp.') as String?,
      isOnline: (data['isOnline'] as bool?) ?? false,
      lastSeen: lastSeen,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastSeen;
    final rawLastSeen = json['lastSeen'];
    if (rawLastSeen != null) {
      if (rawLastSeen is String) {
        lastSeen = DateTime.tryParse(rawLastSeen);
      } else if (rawLastSeen is DateTime) {
        lastSeen = rawLastSeen;
      }
    }

    return UserModel(
      id: (json['id'] ?? json['uid'] ?? '') as String,
      name: (json['name'] ?? json['displayName'] ?? 'WhatsApp User') as String,
      email: (json['email'] ?? '') as String,
      avatarUrl: (json['avatarUrl'] ?? json['photoURL']) as String?,
      phoneNumber: json['phoneNumber'] as String?,
      statusMessage: json['statusMessage'] as String?,
      isOnline: (json['isOnline'] as bool?) ?? false,
      lastSeen: lastSeen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'phoneNumber': phoneNumber,
      'statusMessage': statusMessage,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonString) =>
      UserModel.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
