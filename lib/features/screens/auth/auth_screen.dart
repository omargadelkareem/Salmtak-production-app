import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salmtak/core/storage/app_storage.dart';
import 'package:salmtak/features/screens/doctor/clinic_schedule_screen.dart';
import 'package:salmtak/features/screens/doctor/doctor_view.dart';
import 'package:salmtak/features/screens/patient/patient_view.dart';

class AuthScreen extends StatefulWidget {
  final String role;
  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const Color kPrimary = Color(0xFF0F766E);
  static const Color kPrimary2 = Color(0xFF115E59);

  late TabController _tabController;

  final _formKeyLogin = GlobalKey<FormState>();
  final _formKeyRegister = GlobalKey<FormState>();

  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('users');

  String phone = '';
  String password = '';
  String confirmPassword = '';

  String firstName = '';
  String lastName = '';
  String name = '';
  String photoUrl = '';
  String recoveryCode = '';

  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _confirmObscure = true;

  File? _pickedImage;
  bool isUploadingImage = false;

  String? selectedSpecialization;
  String? selectedSubSpecialization;

  bool hasAssistantDoctor = false;
  String assistantDoctorName = '';
  String assistantDoctorPhone = '';

  String? selectedGovernorate;
  String? selectedCenter;
  String detailedAddress = '';
  String clinicPhone = '';
  String clinicPrice = '';
  String aboutDoctor = '';

  bool hasSecondClinic = false;
  String? selectedGovernorate2;
  String? selectedCenter2;
  String detailedAddress2 = '';
  String clinicPhone2 = '';
  String clinicPrice2 = '';

  bool isLoading = false;

  final GetStorage _storage = GetStorage();
  final ImagePicker _picker = ImagePicker();

  final List<String> allSpecializations = [
    'أطفال وحديثي الولادة',
    'أنف وأذن وحنجرة',
    'أسنان',
    'باطنة',
    'جلدية وتناسلية',
    'قلب وأوعية دموية',
    'مخ وأعصاب',
    'نساء وتوليد',
    'عظام',
    'علاج طبيعي',
    'جراحة عامة',
    'الأشعة التداخلية',
    'الرئة',
    'أورام',
    'أورام الثدي',
    'أمراض دم',
    'جهاز هضمي ومناظير',
    'جراحة أطفال',
    'جراحة أورام',
    'جراحة أوعية دموية',
    'جراحة تجميل',
    'جراحة سمنة ومناظير',
    'جراحة عمود فقري',
    'جراحة قلب وصدر',
    'جراحة مخ وأعصاب',
    'جراحة الوجه والفكين',
    'حساسية ومناعة',
    'حقن مجهري وأطفال أنابيب',
    'ذكورة وعقم',
    'سكّر وغدد صماء',
    'سمعيات',
    'صدر وجهاز تنفسي',
    'علاج الإدمان',
    'علاج الآلام',
    'علاج بالأكسجين',
    'علاج طبيعي وإصابات ملاعب',
    'طب الأسرة',
    'طب العام والحساسية',
    'طب المسنين',
    'طب النفسى',
    'طب نفسى الأطفال',
    'تغذيه',
    'طب التجديدي',
    'طب تقويمي',
    'طب النووى',
    'عيون',
    'كبد',
    'كُلى',
    'مراكز أشعة',
    'مسالك بولية',
    'معامل تحاليل',
    'ممارسة عامة',
    'نطق وتخاطب',
  ];

  final List<String> governorates = [
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'الوادي الجديد',
  ];

  final Map<String, List<String>> centersByGovernorate = {
    'الفيوم': [
      'الفيوم',
      'سنورس',
      'إطسا',
      'طامية',
      'أبشواي',
      'يوسف الصديق',
    ],
    'بني سويف': [
      'بني سويف',
      'الواسطى',
      'ناصر',
      'إهناسيا',
      'ببا',
      'سمسطا',
      'الفشن',
    ],
    'المنيا': [
      'المنيا',
      'العدوة',
      'مغاغة',
      'بني مزار',
      'مطاي',
      'سمالوط',
      'أبو قرقاص',
      'ملوي',
      'دير مواس',
    ],
    'أسيوط': [
      'أسيوط',
      'ديروط',
      'القوصية',
      'منفلوط',
      'أبنوب',
      'الفتح',
      'أبو تيج',
      'الغنايم',
      'ساحل سليم',
      'البداري',
      'صدفا',
    ],
    'سوهاج': [
      'سوهاج',
      'أخميم',
      'ساقلتة',
      'المراغة',
      'طهطا',
      'طما',
      'جهينة',
      'المنشأة',
      'العسيرات',
      'جرجا',
      'البلينا',
      'دار السلام',
    ],
    'قنا': [
      'قنا',
      'أبو تشت',
      'فرشوط',
      'نجع حمادي',
      'دشنا',
      'الوقف',
      'قفط',
      'قوص',
      'نقادة',
    ],
    'الأقصر': [
      'الأقصر',
      'الزينية',
      'البياضية',
      'القرنة',
      'أرمنت',
      'الطود',
      'إسنا',
    ],
    'أسوان': [
      'أسوان',
      'دراو',
      'كوم أمبو',
      'نصر النوبة',
      'إدفو',
    ],
    'الوادي الجديد': [
      'الخارجة',
      'الداخلة',
      'الفرافرة',
      'بلاط',
      'باريس',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.role == 'doctor') {
      photoUrl = '';
    } else {
      photoUrl = '';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _pickedImage = File(pickedFile.path));
    }
  }

  Future<String?> _convertToBase64(File image) async {
    try {
      setState(() => isUploadingImage = true);

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      return 'data:image/jpeg;base64,$base64Image';
    } catch (e) {
      print('خطأ تحويل الصورة: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() => isUploadingImage = false);
      }
    }
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  String _generateRecoveryCode() {
    final random = Random.secure();
    return List<int>.generate(8, (_) => random.nextInt(10)).join();
  }

  Future<void> _saveUserSession(String userId, String role) async {
    await AppStorage.saveUserSession(userId, role);
  }

  Future<void> _clearUserSession() async {
    await _storage.remove('userId');
    await _storage.remove('role');
    await _storage.remove('userRole');
    await _storage.remove('isLoggedIn');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade600),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green.shade600),
    );
  }

  Future<void> _showRecoveryCodeDialog(String code,
      {String title = 'كود الاسترجاع'}) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'احتفظ بهذا الكود في مكان آمن',
              style: TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (mounted) {
                Navigator.pop(context);
                _showSuccess('تم نسخ الكود');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('نسخ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPendingDialogThenEnterGuest() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('الحساب قيد المراجعة'),
        content: const Text(
          'حساب الطبيب لم تتم الموافقة عليه بعد.\n'
          'يمكنك تصفح التطبيق كضيف لحين الموافقة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متابعة كضيف'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PatientView()),
    );
  }

  // =========================
  // عرض كود الاسترجاع الحالي
  // =========================
  Future<void> _openViewRecoveryCodeSheet() async {
    final phoneCtrl = TextEditingController(text: phone.trim());
    final passCtrl = TextEditingController();

    bool obscure = true;
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'عرض كود الاسترجاع',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أدخل رقم التليفون وكلمة المرور الحالية لعرض الكود',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم التليفون',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: kPrimary,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final p = phoneCtrl.text.trim();
                                final pass = passCtrl.text.trim();

                                if (p.isEmpty) {
                                  _showError('اكتب رقم التليفون');
                                  return;
                                }
                                if (pass.length < 6) {
                                  _showError(
                                      'اكتب كلمة مرور صحيحة لا تقل عن 6 أحرف/أرقام');
                                  return;
                                }

                                setLocal(() => loading = true);

                                try {
                                  final snap = await _dbRef
                                      .orderByChild('phone')
                                      .equalTo(p)
                                      .once();

                                  if (snap.snapshot.value == null ||
                                      !snap.snapshot.exists) {
                                    _showError('رقم التليفون غير مسجل');
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final Map<Object?, Object?> data = snap
                                      .snapshot.value as Map<Object?, Object?>;

                                  final entry = data.entries.first;
                                  final userData =
                                      entry.value as Map<Object?, Object?>;

                                  final String userRole =
                                      (userData['role'] ?? '').toString();

                                  if (userRole != widget.role) {
                                    _showError(
                                      'هذا الحساب مخصص لـ ${userRole == 'doctor' ? 'طبيب' : 'مريض'}',
                                    );
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final salt =
                                      (userData['salt'] ?? '').toString();
                                  final storedHash =
                                      (userData['passwordHash'] ?? '')
                                          .toString();

                                  final enteredHash = _hashPassword(pass, salt);

                                  if (enteredHash != storedHash) {
                                    _showError('كلمة المرور غير صحيحة');
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final code = (userData['recoveryCode'] ?? '')
                                      .toString();

                                  if (ctx.mounted) Navigator.pop(ctx);

                                  if (code.isEmpty) {
                                    _showError(
                                        'لا يوجد كود استرجاع لهذا الحساب');
                                    return;
                                  }

                                  await _showRecoveryCodeDialog(
                                    code,
                                    title: 'كود الاسترجاع الحالي',
                                  );
                                } catch (e) {
                                  _showError('حدث خطأ أثناء جلب كود الاسترجاع');
                                } finally {
                                  if (ctx.mounted) {
                                    setLocal(() => loading = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'عرض الكود',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // FORGOT PASSWORD
  // =========================
  Future<void> _openForgotPasswordSheet() async {
    final phoneCtrl = TextEditingController(text: phone.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    bool obscure = true;
    bool loading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'استرجاع كلمة المرور',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم التليفون',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: InputDecoration(
                        labelText: 'كود الاسترجاع (Recovery Code)',
                        prefixIcon: const Icon(Icons.key_rounded),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'كلمة مرور جديدة',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setLocal(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: kPrimary,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final p = phoneCtrl.text.trim();
                                final c = codeCtrl.text.trim();
                                final np = newPassCtrl.text.trim();

                                if (p.isEmpty) {
                                  _showError('اكتب رقم التليفون');
                                  return;
                                }
                                if (c.isEmpty) {
                                  _showError('اكتب كود الاسترجاع');
                                  return;
                                }
                                if (np.length < 6) {
                                  _showError(
                                      'كلمة السر يجب أن تكون 6 أحرف/أرقام على الأقل');
                                  return;
                                }

                                setLocal(() => loading = true);

                                try {
                                  final snap = await _dbRef
                                      .orderByChild('phone')
                                      .equalTo(p)
                                      .once();

                                  if (snap.snapshot.value == null ||
                                      !snap.snapshot.exists) {
                                    _showError('رقم التليفون غير مسجل');
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final Map<Object?, Object?> data = snap
                                      .snapshot.value as Map<Object?, Object?>;

                                  final entry = data.entries.first;
                                  final userId = entry.key.toString();
                                  final userData =
                                      entry.value as Map<Object?, Object?>;

                                  final String userRole =
                                      (userData['role'] ?? '').toString();

                                  if (userRole != widget.role) {
                                    _showError(
                                      'هذا الحساب مخصص لـ ${userRole == 'doctor' ? 'طبيب' : 'مريض'}',
                                    );
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final storedCode =
                                      (userData['recoveryCode'] ?? '')
                                          .toString();

                                  if (storedCode.isEmpty) {
                                    _showError(
                                      'هذا الحساب قديم ولا يملك كود استرجاع.\nتواصل مع الإدارة.',
                                    );
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  if (storedCode != c) {
                                    _showError('كود الاسترجاع غير صحيح');
                                    setLocal(() => loading = false);
                                    return;
                                  }

                                  final newSalt = _generateSalt();
                                  final newHash = _hashPassword(np, newSalt);

                                  // مهم: توليد كود جديد بعد تغيير كلمة المرور
                                  final newRecoveryCode =
                                      _generateRecoveryCode();

                                  await _dbRef.child(userId).update({
                                    'salt': newSalt,
                                    'passwordHash': newHash,
                                    'recoveryCode': newRecoveryCode,
                                    'updatedAt': ServerValue.timestamp,
                                  });

                                  if (ctx.mounted) Navigator.pop(ctx);

                                  _showSuccess('تم تغيير كلمة المرور بنجاح ✅');

                                  await _showRecoveryCodeDialog(
                                    newRecoveryCode,
                                    title: 'كود الاسترجاع الجديد',
                                  );
                                } catch (e) {
                                  _showError(
                                      'حدث خطأ أثناء استرجاع كلمة المرور');
                                } finally {
                                  if (ctx.mounted) {
                                    setLocal(() => loading = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'تغيير كلمة المرور',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // LOGIN
  // =========================
  Future<void> _login() async {
    if (!_formKeyLogin.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final normalizedPhone = phone.trim();

      final snapshot =
          await _dbRef.orderByChild('phone').equalTo(normalizedPhone).once();

      if (snapshot.snapshot.value == null || !snapshot.snapshot.exists) {
        _showError('رقم التليفون غير مسجل');
        setState(() => isLoading = false);
        return;
      }

      final Map<Object?, Object?> data =
          snapshot.snapshot.value as Map<Object?, Object?>;

      final userEntry = data.entries.first;
      final String userId = userEntry.key.toString();

      final Map<Object?, Object?> userData =
          userEntry.value as Map<Object?, Object?>;
      final String userRole = (userData['role'] ?? '').toString();

      if (userRole != widget.role) {
        _showError(
          'هذا الحساب مخصص لـ ${userRole == 'doctor' ? 'طبيب' : 'مريض'}',
        );
        setState(() => isLoading = false);
        return;
      }

      final String storedHash = (userData['passwordHash'] ?? '').toString();
      final String salt = (userData['salt'] ?? '').toString();
      final String calculatedHash = _hashPassword(password, salt);

      if (storedHash != calculatedHash) {
        _showError('كلمة المرور غير صحيحة');
        setState(() => isLoading = false);
        return;
      }

      if (!mounted) return;

      if (widget.role == 'doctor') {
        final bool isApproved = userData['isApproved'] == true;

        if (isApproved) {
          await _saveUserSession(userEntry.key as String, 'doctor');

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DoctorViewPro()),
          );
        } else {
          await _clearUserSession();
          await _storage.write('pendingDoctorId', userEntry.key as String);

          if (!mounted) return;
          await _showPendingDialogThenEnterGuest();
        }
      } else {
        await _saveUserSession(userId, 'patient');

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientView()),
        );
      }
    } catch (e) {
      print('خطأ في تسجيل الدخول: $e');
      _showError('حدث خطأ أثناء تسجيل الدخول');
    }

    if (mounted) setState(() => isLoading = false);
  }

  // =========================
  // REGISTER
  // =========================
  Future<void> _register() async {
    if (!_formKeyRegister.currentState!.validate()) return;

    name = '${firstName.trim()} ${lastName.trim()}'.trim();

    if (password.trim() != confirmPassword.trim()) {
      _showError('كلمة المرور وتأكيد كلمة المرور غير متطابقين');
      return;
    }

    if (widget.role == 'doctor') {
      if (selectedSpecialization == null) {
        _showError('يرجى اختيار التخصص');
        return;
      }

      if (selectedSubSpecialization != null &&
          selectedSubSpecialization == selectedSpecialization) {
        _showError('التخصص الفرعي يجب أن يكون مختلف عن التخصص الرئيسي');
        return;
      }

      if (hasAssistantDoctor) {
        if (assistantDoctorName.trim().isEmpty ||
            assistantDoctorPhone.trim().isEmpty) {
          _showError('يرجى إدخال بيانات الطبيب المساعد (الاسم + رقم الهاتف)');
          return;
        }
      }

      if (selectedGovernorate == null || selectedCenter == null) {
        _showError('يرجى اختيار المحافظة والمركز');
        return;
      }

      if (detailedAddress.trim().isEmpty ||
          clinicPhone.trim().isEmpty ||
          clinicPrice.isEmpty) {
        _showError('يرجى ملء جميع بيانات العيادة الرئيسية');
        return;
      }

      if (hasSecondClinic) {
        if (selectedGovernorate2 == null || selectedCenter2 == null) {
          _showError('يرجى اختيار محافظة/مركز العيادة الثانية');
          return;
        }
        if (detailedAddress2.trim().isEmpty ||
            clinicPhone2.trim().isEmpty ||
            clinicPrice2.trim().isEmpty) {
          _showError('يرجى إدخال عنوان + هاتف + سعر العيادة الثانية');
          return;
        }
      }

      if (_pickedImage == null) {
        _showError('يرجى رفع صورة شخصية للطبيب');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final checkSnapshot =
          await _dbRef.orderByChild('phone').equalTo(phone.trim()).once();

      if (checkSnapshot.snapshot.exists) {
        _showError('رقم التليفون مستخدم بالفعل');
        setState(() => isLoading = false);
        return;
      }

      if (widget.role == 'doctor' && _pickedImage != null) {
        final String? base64Image = await _convertToBase64(_pickedImage!);
        if (base64Image != null) {
          photoUrl = base64Image;
        } else {
          _showError('فشل رفع الصورة، حاول مرة أخرى');
          setState(() => isLoading = false);
          return;
        }
      } else if (widget.role != 'doctor') {
        if (_pickedImage != null) {
          final String? base64Image = await _convertToBase64(_pickedImage!);
          if (base64Image != null) photoUrl = base64Image;
        }
      }

      final salt = _generateSalt();
      final passwordHash = _hashPassword(password, salt);
      recoveryCode = _generateRecoveryCode();

      final newUserRef = _dbRef.push();

      Map<String, dynamic> userData = {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'name': name.trim(),
        'phone': phone.trim(),
        'photoUrl': photoUrl,
        'role': widget.role,
        'salt': salt,
        'passwordHash': passwordHash,
        'recoveryCode': recoveryCode,
        'createdAt': ServerValue.timestamp,
        'isApproved': widget.role == 'doctor' ? false : true,
      };

      if (widget.role == 'doctor') {
        final clinics = <Map<String, dynamic>>[
          {
            'governorate': selectedGovernorate,
            'center': selectedCenter,
            'detailedAddress': detailedAddress.trim(),
            'clinicPhone': clinicPhone.trim(),
            'price': int.tryParse(clinicPrice) ?? 300,
            'schedule': {},
          }
        ];

        if (hasSecondClinic) {
          clinics.add({
            'governorate': selectedGovernorate2,
            'center': selectedCenter2,
            'detailedAddress': detailedAddress2.trim(),
            'clinicPhone': clinicPhone2.trim(),
            'price': int.tryParse(clinicPrice2) ?? 300,
            'schedule': {},
          });
        }

        Map<String, dynamic>? assistantData;
        if (hasAssistantDoctor) {
          assistantData = {
            'name': assistantDoctorName.trim(),
            'phone': assistantDoctorPhone.trim(),
          };
        }

        userData.addAll({
          'specialization': selectedSpecialization,
          'subSpecialization': selectedSubSpecialization,
          'assistantDoctor': assistantData,
          'about': aboutDoctor.trim(),
          'clinics': clinics,
          'rating': 0.0,
          'reviewsCount': 0,
        });
      }

      await newUserRef.set(userData);

      _showSuccess('تم إنشاء الحساب بنجاح!');

      if (!mounted) return;
      await _showRecoveryCodeDialog(
        recoveryCode,
        title: 'مهم جداً ✅ كود الاسترجاع',
      );

      if (!mounted) return;

      if (widget.role == 'doctor') {
        await _clearUserSession();
        await _storage.write('pendingDoctorId', newUserRef.key!);

        final clinicsCount = hasSecondClinic ? 2 : 1;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicScheduleScreen(
              doctorId: newUserRef.key!,
              clinicIndex: 0,
              clinicsCount: clinicsCount,
              primaryColor: kPrimary,
            ),
          ),
        );
      } else {
        await _saveUserSession(newUserRef.key!, 'patient');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientView()),
        );
      }
    } catch (e) {
      print('خطأ في إنشاء الحساب: $e');
      _showError('حدث خطأ أثناء إنشاء الحساب');
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDoctor = widget.role == 'doctor';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _MedicalAuthHeader(
              isDoctor: isDoctor,
              primary: kPrimary,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
              child: _ModernAuthTabs(
                controller: _tabController,
                primary: kPrimary,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildLoginForm(),
                  _buildRegisterForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
      child: Form(
        key: _formKeyLogin,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE5ECEE)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.055),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.role == 'doctor'
                    ? 'مرحبًا بك يا دكتور'
                    : 'مرحبًا بعودتك',
                style: const TextStyle(
                  color: Color(0xFF12343B),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.role == 'doctor'
                    ? 'سجّل الدخول لإدارة عياداتك ومواعيدك'
                    : 'سجّل الدخول لمتابعة حجوزاتك ومواعيدك',
                style: const TextStyle(
                  color: Color(0xFF71838A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _buildTextField(
                label: 'رقم الهاتف',
                icon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                onChanged: (v) => phone = v.trim(),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                obscureText: _loginObscure,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _loginObscure = !_loginObscure),
                  icon: Icon(
                    _loginObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF64748B),
                    size: 21,
                  ),
                ),
                onChanged: (v) => password = v,
                validator: (v) => (v ?? '').length < 6
                    ? 'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: isLoading ? null : _openForgotPasswordSheet,
                    style: TextButton.styleFrom(
                      foregroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 7,
                      ),
                    ),
                    child: const Text(
                      'نسيت كلمة المرور؟',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: isLoading ? null : _openViewRecoveryCodeSheet,
                    icon: const Icon(Icons.shield_outlined, size: 16),
                    label: const Text('كود الاسترجاع'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 7,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PrimaryAuthButton(
                title: 'تسجيل الدخول',
                loading: isLoading,
                onPressed: isLoading ? null : _login,
                primary: kPrimary,
                icon: Icons.login_rounded,
              ),
              const SizedBox(height: 16),
              const _SecurityHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 48),
      child: Form(
        key: _formKeyRegister,
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: kPrimary.withOpacity(0.12),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (photoUrl.startsWith('data:image')
                            ? MemoryImage(
                                base64Decode(photoUrl.split(',').last))
                            : (photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null)) as ImageProvider?,
                    child: (_pickedImage == null &&
                            !photoUrl.startsWith('data:image'))
                        ? const Icon(Icons.person, size: 56, color: kPrimary)
                        : null,
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: isUploadingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.role == 'doctor') ...[
              const SizedBox(height: 12),
              const Text(
                'مطلوب رفع صورة شخصية واضحة للطبيب',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),
            _buildTextField(
              label: 'الاسم الأول',
              icon: Icons.person_outline,
              onChanged: (v) => firstName = v.trim(),
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'الاسم الثاني',
              icon: Icons.person_outline,
              onChanged: (v) => lastName = v.trim(),
              validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'رقم التليفون (الشخصي)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              onChanged: (v) => phone = v.trim(),
              validator: (v) => (v ?? '').isEmpty ? 'مطلوب' : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'كلمة المرور',
              icon: Icons.lock_outline,
              obscureText: _registerObscure,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _registerObscure = !_registerObscure),
                icon: Icon(
                  _registerObscure ? Icons.visibility_off : Icons.visibility,
                  color: kPrimary,
                ),
              ),
              onChanged: (v) => password = v,
              validator: (v) => (v ?? '').length < 6
                  ? 'كلمة السر يجب أن تكون 6 أحرف/أرقام على الأقل'
                  : null,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'تأكيد كلمة المرور',
              icon: Icons.lock_reset_outlined,
              obscureText: _confirmObscure,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _confirmObscure = !_confirmObscure),
                icon: Icon(
                  _confirmObscure ? Icons.visibility_off : Icons.visibility,
                  color: kPrimary,
                ),
              ),
              onChanged: (v) => confirmPassword = v,
              validator: (v) {
                final vv = (v ?? '').trim();
                if (vv.length < 6) return 'أدخل 6 أحرف/أرقام على الأقل';
                if (vv != password.trim()) return 'كلمة السر غير متطابقة';
                return null;
              },
            ),
            if (widget.role == 'doctor') ...[
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                value: selectedSpecialization,
                hint: const Text('اختر التخصص الرئيسي'),
                isExpanded: true,
                decoration: _dropdownDecoration('التخصص الرئيسي'),
                items: allSpecializations
                    .map((spec) =>
                        DropdownMenuItem(value: spec, child: Text(spec)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSpecialization = value;
                    if (selectedSubSpecialization == selectedSpecialization) {
                      selectedSubSpecialization = null;
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'يرجى اختيار التخصص' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedSubSpecialization,
                hint: const Text('اختر التخصص الفرعي (اختياري)'),
                isExpanded: true,
                decoration: _dropdownDecoration('التخصص الفرعي (اختياري)'),
                items: allSpecializations
                    .where((s) => s != selectedSpecialization)
                    .map((spec) =>
                        DropdownMenuItem(value: spec, child: Text(spec)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => selectedSubSpecialization = value),
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                title: const Text(
                  'لدي طبيب مساعد',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'سيظهر للمريض كوسيلة تواصل إضافية داخل العيادة (اختياري)',
                ),
                value: hasAssistantDoctor,
                onChanged: (value) {
                  setState(() {
                    hasAssistantDoctor = value ?? false;
                    if (!hasAssistantDoctor) {
                      assistantDoctorName = '';
                      assistantDoctorPhone = '';
                    }
                  });
                },
                activeColor: kPrimary,
                contentPadding: EdgeInsets.zero,
              ),
              if (hasAssistantDoctor) ...[
                const SizedBox(height: 10),
                _buildTextField(
                  label: 'اسم الطبيب المساعد',
                  icon: Icons.person_outline,
                  onChanged: (v) => assistantDoctorName = v.trim(),
                  validator: (v) {
                    if (!hasAssistantDoctor) return null;
                    return (v ?? '').trim().isEmpty ? 'مطلوب' : null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'رقم هاتف الطبيب المساعد',
                  icon: Icons.phone_in_talk_outlined,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => assistantDoctorPhone = v.trim(),
                  validator: (v) {
                    if (!hasAssistantDoctor) return null;
                    return (v ?? '').trim().isEmpty ? 'مطلوب' : null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              _buildTextField(
                label: 'نبذة عنك (اختياري)',
                icon: Icons.info_outline,
                maxLines: 4,
                onChanged: (v) => aboutDoctor = v,
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              const Text(
                'العيادة الرئيسية',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedGovernorate,
                hint: const Text('اختر المحافظة'),
                decoration: _dropdownDecoration('المحافظة'),
                items: governorates
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGovernorate = value;
                    selectedCenter = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'يرجى اختيار المحافظة' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedCenter,
                hint: const Text('اختر المركز / المدينة'),
                decoration: _dropdownDecoration('المركز'),
                items: selectedGovernorate == null
                    ? []
                    : centersByGovernorate[selectedGovernorate]!
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: selectedGovernorate == null
                    ? null
                    : (value) => setState(() => selectedCenter = value),
                validator: (value) =>
                    value == null ? 'يرجى اختيار المركز' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'العنوان بالتفصيل (شارع، رقم، معلم)',
                icon: Icons.location_on_outlined,
                onChanged: (v) => detailedAddress = v.trim(),
                validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'رقم تليفون العيادة (سيظهر للمرضى)',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                onChanged: (v) => clinicPhone = v.trim(),
                validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                label: 'سعر الكشف (جنيه)',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                onChanged: (v) => clinicPrice = v,
                validator: (v) => (v ?? '').isEmpty || int.tryParse(v!) == null
                    ? 'أدخل رقم صحيح'
                    : null,
              ),
              const SizedBox(height: 14),
              CheckboxListTile(
                title: const Text(
                  'لدي عيادة أخرى',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                value: hasSecondClinic,
                onChanged: (value) {
                  setState(() {
                    hasSecondClinic = value ?? false;
                    if (!hasSecondClinic) {
                      selectedGovernorate2 = null;
                      selectedCenter2 = null;
                      detailedAddress2 = '';
                      clinicPhone2 = '';
                      clinicPrice2 = '';
                    }
                  });
                },
                activeColor: kPrimary,
              ),
              if (hasSecondClinic) ...[
                const SizedBox(height: 16),
                const Text(
                  'العيادة الثانية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGovernorate2,
                  hint: const Text('اختر المحافظة'),
                  decoration: _dropdownDecoration('المحافظة'),
                  items: governorates
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGovernorate2 = value;
                      selectedCenter2 = null;
                    });
                  },
                  validator: (v) =>
                      hasSecondClinic && v == null ? 'مطلوب' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedCenter2,
                  hint: const Text('اختر المركز / المدينة'),
                  decoration: _dropdownDecoration('المركز'),
                  items: selectedGovernorate2 == null
                      ? []
                      : centersByGovernorate[selectedGovernorate2]!
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                  onChanged: selectedGovernorate2 == null
                      ? null
                      : (value) => setState(() => selectedCenter2 = value),
                  validator: (v) =>
                      hasSecondClinic && v == null ? 'مطلوب' : null,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'العنوان بالتفصيل',
                  icon: Icons.location_on_outlined,
                  onChanged: (v) => detailedAddress2 = v.trim(),
                  validator: (v) => hasSecondClinic && (v ?? '').trim().isEmpty
                      ? 'مطلوب'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'رقم تليفون العيادة',
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => clinicPhone2 = v.trim(),
                  validator: (v) => hasSecondClinic && (v ?? '').trim().isEmpty
                      ? 'مطلوب'
                      : null,
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'سعر الكشف (جنيه)',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => clinicPrice2 = v,
                  validator: (v) => hasSecondClinic &&
                          ((v ?? '').isEmpty || int.tryParse(v!) == null)
                      ? 'أدخل رقم صحيح'
                      : null,
                ),
              ],
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading || isUploadingImage ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: isLoading || isUploadingImage
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'جاري الإنشاء...',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'إنشاء الحساب',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: const Icon(
        Icons.local_hospital_outlined,
        color: kPrimary,
        size: 21,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    required Function(String) onChanged,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      cursorColor: kPrimary,
      style: const TextStyle(
        color: Color(0xFF172B31),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(icon, color: kPrimary, size: 21),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: kPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.4),
        ),
      ),
    );
  }
}

class _MedicalAuthHeader extends StatelessWidget {
  const _MedicalAuthHeader({
    required this.isDoctor,
    required this.primary,
  });

  final bool isDoctor;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -44,
            end: -34,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Icon(
                  isDoctor
                      ? Icons.medical_services_rounded
                      : Icons.health_and_safety_rounded,
                  color: primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'سلامتك',
                      style: TextStyle(
                        color: Color(0xFFCCFBF1),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDoctor ? 'بوابة الأطباء' : 'رعايتك تبدأ من هنا',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isDoctor
                          ? 'إدارة العيادات والمواعيد والحجوزات بسهولة'
                          : 'ابحث عن الطبيب المناسب واحجز موعدك بأمان',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 10.8,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernAuthTabs extends StatelessWidget {
  const _ModernAuthTabs({
    required this.controller,
    required this.primary,
  });

  final TabController controller;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EFF0),
        borderRadius: BorderRadius.circular(17),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: primary,
        unselectedLabelColor: const Color(0xFF71838A),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        tabs: const [
          Tab(text: 'تسجيل الدخول'),
          Tab(text: 'إنشاء حساب'),
        ],
      ),
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({
    required this.title,
    required this.loading,
    required this.onPressed,
    required this.primary,
    required this.icon,
  });

  final String title;
  final bool loading;
  final VoidCallback? onPressed;
  final Color primary;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primary,
          disabledBackgroundColor: primary.withOpacity(0.55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SecurityHint extends StatelessWidget {
  const _SecurityHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF0F766E),
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'بياناتك محفوظة ومشفرة ولا يتم مشاركتها مع أي طرف.',
              style: TextStyle(
                color: Color(0xFF426067),
                fontSize: 10.3,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
