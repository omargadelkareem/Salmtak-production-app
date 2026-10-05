import 'package:flutter/material.dart';

class DoctorPendingApprovalScreen extends StatelessWidget {
  const DoctorPendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 120,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 40),
              const Text(
                'في انتظار الموافقة',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'تم إنشاء حسابك بنجاح!\n'
                'الآن في انتظار موافقة الإدارة على حسابك كطبيب.\n'
                'سيتم إشعارك بمجرد الموافقة.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  // تسجيل خروج وارجع لاختيار الدور
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/role-selection', // أو المسار بتاع RoleSelectionScreen
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
