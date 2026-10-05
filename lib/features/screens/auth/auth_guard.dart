
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/app_storage.dart';
import '../role/role_selected_screen.dart';

class AuthGuard {
  static Future<bool> requireLogin(BuildContext context) async {
    final userId = AppStorage.getUserId();
    final userRole = AppStorage.getUserRole();

    // ✅ Logged in
    if (userId != null && userId.isNotEmpty && userRole != null) {
      return true;
    }

    // ✅ Guest → اظهر Dialog
    final shouldGo = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('لازم تسجل الأول'),
          content: const Text(
            'علشان تكمل الحجز لازم تعمل تسجيل دخول أو إنشاء حساب.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              child: const Text('تسجيل'),
            ),
          ],
        );
      },
    );

    if (shouldGo == true && context.mounted) {
      // ✅ رجعه لاختيار الـ Role
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }

    return false;
  }
}
