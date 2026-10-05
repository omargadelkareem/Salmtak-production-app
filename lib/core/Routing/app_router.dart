
import 'package:flutter/material.dart';

import '../../features/screens/auth/auth_screen.dart';
import '../../features/screens/doctor/doctor_view.dart';
import '../../features/screens/patient/patient_view.dart';
import '../../features/screens/role/role_selected_screen.dart';
import '../../features/screens/splash/splash_screen.dart';

class AppRoutes {
  // أسماء الروتس (عشان نستخدمها في كل التطبيق)
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String auth = '/auth';
  static const String patientHome = '/patient-home';
  static const String doctorHome = '/doctor-home';

  // دالة لإنشاء الروت حسب الاسم
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());

      case auth:
        // نستقبل الـ role كـ argument
        final String role = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => AuthScreen(role: role),
        );

      case patientHome:
        return MaterialPageRoute(builder: (_) => const PatientView());

      case doctorHome:
        return MaterialPageRoute(builder: (_) => const DoctorViewPro());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('الصفحة غير موجودة: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
