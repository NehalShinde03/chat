import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? phoneNumber;
  final String? statusMessage;
  final bool isOnline;
  final DateTime? lastSeen;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.phoneNumber,
    this.statusMessage,
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        avatarUrl,
        phoneNumber,
        statusMessage,
        isOnline,
        lastSeen,
      ];
}
