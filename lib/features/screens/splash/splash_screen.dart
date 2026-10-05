import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/storage/app_storage.dart';
import '../doctor/doctor_view.dart';
import '../patient/patient_view.dart';
import '../pending_approval_screen.dart';

/// ✅ Teal Theme Colors
const Color kTealDark = Color(0xFF0F766E);
const Color kTeal = Color(0xFF14B8A6);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    /// ✅ Fade animation بسيطة وهادية
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _fade = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkLoggedInUser();
  }

  Future<void> _checkLoggedInUser() async {
    await Future.delayed(const Duration(seconds: 2));
    await GetStorage.init();

    final String? userId = AppStorage.getUserId();
    final String? userRole = AppStorage.getUserRole();

    // ✅ لو في Session → ادخل طبيعي
    if (mounted && userId != null && userId.isNotEmpty && userRole != null) {
      if (userRole == 'doctor') {
        final snap =
            await _dbRef.child('users').child(userId).child('isApproved').get();
        final bool isApproved = snap.value as bool? ?? false;

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isApproved
                ? const DoctorViewPro()
                : const DoctorPendingApprovalScreen(),
          ),
        );
        return;
      }

      // ✅ patient
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PatientView()),
      );
      return;
    }

    // ✅ مفيش Session → ادخل Guest على PatientView
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PatientView()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kTealDark, kTeal],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ✅ Logo Card (Professional)
              Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Image(
                      width: 100,
                      height: 100,
                      image: AssetImage("assets/images/logo.jpeg"))),

              const SizedBox(height: 18),

              // ✅ App Name
              const Text(
                'سلامتك',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 8),

              // ✅ Subtitle
              Text(
                '   حجز اسهل علاج اسرع',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(flex: 2),

              // ✅ Calm Loader (No CircularProgressIndicator)
              FadeTransition(
                opacity: _fade,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Dot(),
                      const SizedBox(width: 6),
                      const _Dot(delay: 120),
                      const SizedBox(width: 6),
                      const _Dot(delay: 240),
                      const SizedBox(width: 10),
                      Text(
                        'جاري التحميل...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ✅ Footer
              Text(
                '© ${DateTime.now().year} Salamtak',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.75),
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// ✅ Tiny Dot Widget (soft and clean)
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scale = Tween<double>(begin: 0.55, end: 1.1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
