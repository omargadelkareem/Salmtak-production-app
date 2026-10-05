import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/home_colors.dart';

class HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const HeaderChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  final bool isGuest;
  final bool isLoading;
  final String userName;
  final String userPhotoUrl;
  final String userGovernorate;
  final String userCenter;
  final VoidCallback onLoginTap;

  const HomeHeader({
    super.key,
    required this.isGuest,
    required this.isLoading,
    required this.userName,
    required this.userPhotoUrl,
    required this.userGovernorate,
    required this.userCenter,
    required this.onLoginTap,
  });

  Future<void> openSupportWhatsApp(BuildContext context) async {
    const phone = '201080505068'; // ✅ لازم كود الدولة (20)
    const message = 'مرحبا، انا مستخدم التطبيق محتاج  دعم فني من فضلك';

    final whatsappAppUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );

    final webUri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      // ✅ جرّب يفتح واتساب مباشرة
      final openedApp = await launchUrl(
        whatsappAppUri,
        mode: LaunchMode.externalApplication,
      );

      // ✅ لو فشل يفتح web
      if (!openedApp) {
        final openedWeb = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );

        if (!openedWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مش قادر أفتح واتساب على الجهاز ده')),
          );
        }
      }
    } catch (e) {
      // ✅ fallback قوي
      final openedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (!openedWeb && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء فتح واتساب: $e')),
        );
      }
    }
  }

  ImageProvider? _safeAvatarProvider(String url) {
    final v = url.trim();
    if (v.isEmpty) return null;

    if (v.startsWith('data:image')) {
      try {
        final bytes = base64Decode(v.split(',').last);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    // network
    return CachedNetworkImageProvider(v);
  }

  @override
  Widget build(BuildContext context) {
    final name = isLoading
        ? '...'
        : userName.trim().isEmpty
            ? 'مستخدم'
            : userName.trim();

    final location = _locationLine();
    final avatarProvider = _safeAvatarProvider(userPhotoUrl);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HomeColors.primaryTealDark, HomeColors.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: avatarProvider == null
                        ? const Icon(Icons.person_rounded, color: Colors.white)
                        : Image(image: avatarProvider, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أهلًا $name 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isGuest
                            ? 'تصفح كضيف، وسجّل عند الحجز'
                            : (location.isEmpty
                                ? 'ابحث عن طبيبك بسهولة'
                                : location),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isGuest)
                  TextButton(
                    onPressed: onLoginTap,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.16),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    child: const Text(
                      'تسجيل',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InkWell(
                  onTap: () async {
                    await openSupportWhatsApp(context);
                  },
                  child: const HeaderChip(
                      icon: Icons.support_agent_rounded, text: ' تواصل معنا'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _locationLine() {
    final g = userGovernorate.trim();
    final c = userCenter.trim();
    if (g.isEmpty && c.isEmpty) return '';
    if (g.isEmpty) return c;
    if (c.isEmpty) return g;
    return '$g • $c';
  }
}
