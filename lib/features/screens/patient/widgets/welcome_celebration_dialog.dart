import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfettiPainter extends CustomPainter {
  final math.Random _r = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 70; i++) {
      final x = _r.nextDouble() * size.width;
      final y = _r.nextDouble() * size.height;
      final radius = 1.5 + (_r.nextDouble() * 3.5);

      final opacity = 0.08 + (_r.nextDouble() * 0.18);

      final colors = [
        const Color(0xFFFFFFFF),
        const Color(0xFF99F6E4),
        const Color(0xFF14B8A6),
        const Color(0xFF0F766E),
      ];

      paint.color = colors[_r.nextInt(colors.length)].withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WelcomeCelebrationDialog extends StatelessWidget {
  final String userName;
  final String governorate;
  final String center;
  final VoidCallback onStart;

  const WelcomeCelebrationDialog({
    required this.userName,
    required this.governorate,
    required this.center,
    required this.onStart,
  });

  static const Color _tealDark = Color(0xFF0F766E);
  static const Color _teal = Color(0xFF14B8A6);

  String get _locationText {
    final g = governorate.trim();
    final c = center.trim();

    if (g.isEmpty && c.isEmpty) return 'جاهز تبدأ رحلتك الطبية ✨';
    if (g.isNotEmpty && c.isEmpty) return 'من $g ✅';
    if (g.isEmpty && c.isNotEmpty) return 'من $c ✅';
    return '$g - $c ✅';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 18),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // خلفية Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        _tealDark,
                        _teal,
                        Color(0xFFECFEFF),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                // Confetti رسم خفيف
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ConfettiPainter(),
                    ),
                  ),
                ),

                // دوائر زينة
                Positioned(
                  top: -60,
                  right: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // المحتوى
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // top row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text("🎉",
                                    style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  "أهلاً وسهلاً",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Icon circle
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 36,
                              color: _tealDark,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "أهلاً يا $userName 👋",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "نورت التطبيق ✨\nدلوقتي تقدر تلاقي أفضل دكتور قريب منك وتحجز بسهولة",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.35,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // location chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _locationText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: onStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _tealDark,
                            elevation: 18,
                            shadowColor: Colors.black.withOpacity(0.28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "يلا نبدأ 🚀",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "تقدر تقفل الرسالة دي في أي وقت ❤️",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
