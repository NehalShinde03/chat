import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../../../core/widgets/custom_avatar.dart';
import '../../data/profile_assets.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String subtitle;
  final ImageProvider? avatarImage;
  final bool showBackButton;

  const ProfilePage({
    super.key,
    this.name = 'Shobith Dubey',
    this.subtitle = 'Owner · Joined Oct 2026',
    this.avatarImage,
    this.showBackButton = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 4; // 'Profile' tab active

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.profileBackground,
        body: SafeArea(
          bottom: false,
          child: ResponsiveLayout(
            mobile: _buildScrollContent(context),
            tablet: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildScrollContent(context),
              ),
            ),
            desktop: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _buildScrollContent(context),
              ),
            ),
          ),
        ),
        bottomNavigationBar: ResponsiveLayout(
          mobile: _buildBottomNavigationBar(context),
          tablet: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildBottomNavigationBar(context),
            ),
          ),
          desktop: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildBottomNavigationBar(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: "Profile" title
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Row(
              children: [
                if (widget.showBackButton && Navigator.canPop(context)) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.profileTextPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                ],
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.profileTextPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          // Hairline divider under title
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.profileDivider,
          ),

          // User Profile Info Section
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Row(
              children: [
                CustomAvatar(
                  radius: 34,
                  imageProvider: widget.avatarImage ??
                      ProfileAssets.referenceAvatarImageProvider,
                  name: widget.name,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.profileTextPrimary,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.profileTextSecondary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Card 1: Property and Management Group
          _ProfileCardGroup(
            children: [
              _ProfileMenuItem(
                icon: Icons.home_outlined,
                title: 'Active Property',
                trailingText: 'Prestige Falcon City',
                onTap: () {},
              ),
              _ProfileMenuItem(
                customIcon: const _HexagonBadgeIcon(),
                title: 'Working as',
                trailingText: 'Owner',
                onTap: () {},
              ),
              _ProfileMenuItem(
                icon: Icons.domain_outlined,
                title: 'Organization',
                trailingText: 'Dubey Estates',
                onTap: () {},
              ),
              _ProfileMenuItem(
                icon: Icons.group_outlined,
                title: 'Team members',
                subtitle: 'Invite and manage staff',
                trailingText: 'Dubey Estates',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Card 2: Roles & Permissions Group
          _ProfileCardGroup(
            children: [
              _ProfileMenuItem(
                icon: Icons.verified_user_outlined,
                title: 'Roles & Permissions',
                subtitle: 'system and custom roles',
                trailingText: 'Dubey Estates',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Card 3: Settings & Preferences Group
          _ProfileCardGroup(
            children: [
              _ProfileMenuItem(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                trailingText: 'On',
                onTap: () {},
              ),
              _ProfileMenuItem(
                icon: Icons.language_outlined,
                title: 'Language',
                trailingText: 'English',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final items = const [
      (Icons.home_outlined, 'Home'),
      (Icons.payments_outlined, 'Rent'),
      (Icons.group_outlined, 'Tenants'),
      (Icons.build_outlined, 'Utilities'),
      (Icons.account_circle_outlined, 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.profileDivider,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomPadding > 0 ? bottomPadding : 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = _selectedIndex == index;
          final color = isSelected
              ? AppColors.profileNavActive
              : AppColors.profileNavInactive;
          final item = items[index];

          return Expanded(
            child: InkResponse(
              onTap: () {
                if (index == 0 && Navigator.canPop(context)) {
                  Navigator.pop(context);
                  return;
                }
                setState(() {
                  _selectedIndex = index;
                });
              },
              radius: 28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$1,
                    size: 22,
                    color: color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProfileCardGroup extends StatelessWidget {
  final List<Widget> children;

  const _ProfileCardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.profileCardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String? subtitle;
  final String trailingText;
  final VoidCallback? onTap;

  const _ProfileMenuItem({
    this.icon,
    this.customIcon,
    required this.title,
    this.subtitle,
    required this.trailingText,
    this.onTap,
  }) : assert(icon != null || customIcon != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.profileIconBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: customIcon ??
                  Icon(
                    icon,
                    size: 20,
                    color: AppColors.profileIcon,
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.profileTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.profileTextSecondary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.profileTextSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.profileTextSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HexagonBadgeIcon extends StatelessWidget {
  const _HexagonBadgeIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _HexagonBadgePainter(color: AppColors.profileIcon),
    );
  }
}

class _HexagonBadgePainter extends CustomPainter {
  final Color color;

  const _HexagonBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.48;

    // Hexagon path with vertical sides and points at top & bottom
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 3);
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();
    canvas.drawPath(hexPath, strokePaint);

    // Inner icon: circular head / badge center
    final headRadius = w * 0.16;
    final headCenter = Offset(cx, cy - h * 0.05);
    canvas.drawCircle(headCenter, headRadius, strokePaint);

    // Inner dot / pin point beneath head
    canvas.drawCircle(Offset(cx, cy + h * 0.16), 1.0, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _HexagonBadgePainter oldDelegate) =>
      oldDelegate.color != color;
}
