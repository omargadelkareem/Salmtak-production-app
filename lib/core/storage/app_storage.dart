import 'package:get_storage/get_storage.dart';

class AppStorage {
  static final _box = GetStorage();

  // حفظ الجلسة
  static Future<void> saveUserSession(String userId, String role) async {
    await _box.write('userId', userId);
    await _box.write('userRole', role);
    print('✅ تم حفظ الجلسة بـ GetStorage');
  }

  // جلب الجلسة
  static String? getUserId() => _box.read('userId');
  static String? getUserRole() => _box.read('userRole');

  // تسجيل الخروج
  static Future<void> clearSession() async {
    await _box.remove('userId');
    await _box.remove('userRole');
  }
}
