import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
  });

  String get _initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Color _generateColor(String text) {
    final colors = [
      Colors.teal,
      Colors.deepOrange,
      Colors.indigo,
      Colors.purple,
      Colors.blueGrey,
      Colors.blue,
      Colors.green,
    ];
    final hash = text.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _generateColor(name),
          backgroundImage: (imageUrl != null && imageUrl!.startsWith('http'))
              ? NetworkImage(imageUrl!)
              : null,
          child: (imageUrl == null || !imageUrl!.startsWith('http'))
              ? Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.75,
                  ),
                )
              : null,
        ),
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: AppColors.greenBadge,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
