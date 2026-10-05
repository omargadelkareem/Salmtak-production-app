import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../role/role_selected_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ✅ Teal palette (local)
  static const Color _teal = Color(0xFF0F766E);
  static const Color _teal2 = Color(0xFF14B8A6);

  // User
  String userName = 'جاري التحميل...';
  String userPhone = '';
  String userRole = ''; // doctor/patient/guest
  String userPhotoUrl = '';
  bool isLoadingUser = true;

  // Medical Records
  bool isLoadingRecords = true;
  bool isUploadingRecord = false;
  List<Map<String, dynamic>> records = [];

  // Filter
  String selectedCategory =
      'all'; // all/prescription/test/certificate/scan/other

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();
  final ImagePicker _picker = ImagePicker();

  String? userId;

  bool get isGuest => (userId == null || (userId ?? '').isEmpty);

  bool get isPatientUser => (!isGuest && userRole != 'doctor');

  @override
  void initState() {
    super.initState();
    userId = _storage.read('userId');

    _loadUserData();

    // ✅ medical records only for real logged patient user
    if (!isGuest) {
      _loadMedicalRecords();
    } else {
      isLoadingRecords = false;
      records = [];
    }
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => isLoadingUser = true);

    try {
      final String? uid = userId;

      // ✅ Guest
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          userName = 'زائر';
          userPhone = '';
          userRole = 'guest';
          userPhotoUrl = '';
          isLoadingUser = false;
        });
        return;
      }

      final snapshot = await _dbRef.child('users').child(uid).get();
      if (!mounted) return;

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<Object?, Object?>.from(snapshot.value as Map);
        setState(() {
          userName = (data['name'] as String?)?.trim() ?? 'مستخدم';
          userPhone = (data['phone'] as String?)?.trim() ?? '';
          userRole = (data['role'] as String?)?.trim() ?? 'patient';
          userPhotoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
          isLoadingUser = false;
        });
      } else {
        setState(() => isLoadingUser = false);
      }
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في جلب بيانات الملف: $e');
      if (!mounted) return;
      setState(() => isLoadingUser = false);
    }
  }

  Future<void> _loadMedicalRecords() async {
    if (!mounted) return;
    setState(() => isLoadingRecords = true);

    try {
      final String? uid = userId;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          records = [];
          isLoadingRecords = false;
        });
        return;
      }

      final snap =
          await _dbRef.child('users').child(uid).child('medicalRecords').get();

      final list = <Map<String, dynamic>>[];

      if (snap.exists && snap.value != null) {
        final raw = snap.value;
        if (raw is Map) {
          final map = Map<Object?, Object?>.from(raw);
          for (final entry in map.entries) {
            if (entry.value is Map) {
              final m = Map<String, dynamic>.from(entry.value as Map);
              m['id'] = entry.key.toString();
              list.add(m);
            }
          }
        }
      }

      list.sort((a, b) {
        final ta =
            (a['createdAt'] is num) ? (a['createdAt'] as num).toInt() : 0;
        final tb =
            (b['createdAt'] is num) ? (b['createdAt'] as num).toInt() : 0;
        return tb.compareTo(ta);
      });

      if (!mounted) return;
      setState(() {
        records = list;
        isLoadingRecords = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في جلب السجل المرضي: $e');
      if (!mounted) return;
      setState(() {
        records = [];
        isLoadingRecords = false;
      });
    }
  }

  // =========================
  // ✅ Profile Image
  // =========================
  ImageProvider _getProfileImageProvider() {
    if (userPhotoUrl.startsWith('data:image')) {
      try {
        final String base64String = userPhotoUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    if (userPhotoUrl.isNotEmpty) {
      return CachedNetworkImageProvider(userPhotoUrl);
    }

    return const AssetImage('assets/images/logo.jpeg');
  }

  // =========================
  // ✅ Guest -> Create Account
  // =========================
  void _goToCreateAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  // =========================
  // ✅ Logout
  // =========================
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _storage.erase();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  // =========================
  // ✅ Edit Profile Helpers
  // =========================
  Future<String?> _pickImageAsDataUrl(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1400,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    return "data:image/jpeg;base64,$b64";
  }

  Future<void> _openEditProfileSheet() async {
    final uid = userId;

    // ✅ Guest ممنوع تعديل
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إنشاء حساب أولاً')),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: userName);
    final phoneCtrl = TextEditingController(text: userPhone);

    bool saving = false;
    String localPhotoUrl = userPhotoUrl;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final cs = Theme.of(context).colorScheme;
            final viewInsets = MediaQuery.of(context).viewInsets.bottom;

            ImageProvider previewProvider() {
              if (localPhotoUrl.startsWith('data:image')) {
                try {
                  final bytes = base64Decode(localPhotoUrl.split(',').last);
                  return MemoryImage(bytes);
                } catch (_) {}
              }
              if (localPhotoUrl.isNotEmpty) {
                return CachedNetworkImageProvider(localPhotoUrl);
              }
              return const AssetImage('assets/images/jj.jpg');
            }

            Future<void> pickPhoto(ImageSource source) async {
              final dataUrl = await _pickImageAsDataUrl(source);
              if (dataUrl == null) return;
              setLocal(() => localPhotoUrl = dataUrl);
            }

            Future<void> save() async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();

              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('من فضلك اكتب الاسم')),
                );
                return;
              }

              setLocal(() => saving = true);
              try {
                await _dbRef.child('users').child(uid).update({
                  'name': newName,
                  'phone': newPhone,
                  'photoUrl': localPhotoUrl,
                });

                if (!context.mounted) return;
                Navigator.pop(context);

                await _loadUserData();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث البيانات ✅')),
                );
              } catch (e) {
                // ignore: avoid_print
                print('خطأ تحديث البيانات: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('حدث خطأ أثناء حفظ البيانات')),
                );
              } finally {
                if (context.mounted) setLocal(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text(
                            'تعديل البيانات',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed:
                                saving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Photo preview + actions
                      Row(
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: previewProvider(),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(
                                  color: cs.outlineVariant.withOpacity(0.35)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                _PrimaryActionButton(
                                  primary: _teal,
                                  label: 'تغيير من المعرض',
                                  icon: Icons.photo_library_rounded,
                                  onTap: saving
                                      ? () {}
                                      : () => pickPhoto(ImageSource.gallery),
                                ),
                                const SizedBox(height: 10),
                                _PrimaryActionButton(
                                  primary: _teal,
                                  label: 'تغيير بالكاميرا',
                                  icon: Icons.photo_camera_rounded,
                                  onTap: saving
                                      ? () {}
                                      : () => pickPhoto(ImageSource.camera),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'الاسم',
                          prefixIcon: const Icon(Icons.person_rounded),
                          filled: true,
                          fillColor:
                              cs.surfaceContainerHighest.withOpacity(0.35),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: _teal, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: const Icon(Icons.phone_rounded),
                          filled: true,
                          fillColor:
                              cs.surfaceContainerHighest.withOpacity(0.35),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.35)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide:
                                const BorderSide(color: _teal, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: saving ? null : save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'حفظ التعديلات',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================
  // ✅ Wallet Topup (NEW ✅)
  // =========================

  Future<void> _openTopUpWalletSheet() async {
    final uid = userId;

    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إنشاء حساب أولاً')),
      );
      return;
    }

    // لو تحب تمنع الطبيب من الشحن
    if (userRole == 'doctor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ميزة الشحن متاحة للمرضى فقط')),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final receiverCtrl = TextEditingController();
    String method = 'instapay'; // instapay | wallet
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setLocal) {
            final insets = MediaQuery.of(sheetContext).viewInsets.bottom;
            final cs = Theme.of(sheetContext).colorScheme;

            Future<void> submit() async {
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              final receiver = receiverCtrl.text.trim();

              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اكتب مبلغ صحيح')),
                );
                return;
              }
              if (receiver.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('اكتب رقم التحويل')),
                );
                return;
              }

              setLocal(() => saving = true);
              try {
                await _createWalletTopupRequest(
                  amount: amount,
                  method: method,
                  receiverNumber: receiver,
                );

                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب الشحن ✅ (بانتظار التأكيد)'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء الإرسال: $e')),
                );
              } finally {
                if (sheetContext.mounted) setLocal(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: insets),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'شحن المحفظة',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'المبلغ (جنيه)',
                        prefixIcon: const Icon(Icons.payments_rounded),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: method,
                      items: const [
                        DropdownMenuItem(
                            value: 'instapay', child: Text('InstaPay')),
                        DropdownMenuItem(value: 'wallet', child: Text('محفظة')),
                      ],
                      onChanged: (v) => setLocal(() => method = v ?? method),
                      decoration: InputDecoration(
                        labelText: 'طريقة التحويل',
                        prefixIcon:
                            const Icon(Icons.account_balance_wallet_rounded),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: receiverCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم التحويل (الرقم اللي هنحولك عليه   )',
                        prefixIcon: const Icon(Icons.phone_rounded),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'إرسال طلب الشحن',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سيظهر الطلب في الداشبورد للمراجعة ثم يتم إضافة الرصيد بعد التأكيد.',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createWalletTopupRequest({
    required int amount,
    required String method, // instapay | wallet
    required String receiverNumber,
  }) async {
    final uid = userId!;
    final now = DateTime.now().millisecondsSinceEpoch;

    final topupRef = _dbRef.child('walletTopups').push();
    final topupId = topupRef.key!;

    final payload = <String, dynamic>{
      'id': topupId,
      'userId': uid,
      'userName': userName,
      'userPhone': userPhone,
      'amount': amount,
      'method': method,
      'receiverNumber': receiverNumber,
      'status': 'pending', // pending | confirmed | rejected
      'createdAt': now,
      'updatedAt': now,
    };

    final updates = <String, dynamic>{
      'walletTopups/$topupId': payload,
      'userWalletTopups/$uid/$topupId': true,
    };

    await _dbRef.update(updates);
  }

  // =========================
  // ✅ Medical Records Actions
  // =========================

  List<Map<String, dynamic>> get _filteredRecords {
    if (selectedCategory == 'all') return records;
    return records
        .where((r) => (r['category'] ?? '').toString() == selectedCategory)
        .toList();
  }

  ImageProvider _imageProviderFromDataUrl(String dataUrl) {
    try {
      final base64String = dataUrl.split(',').last;
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (_) {
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'prescription':
        return 'روشتة';
      case 'test':
        return 'تحليل';
      case 'certificate':
        return 'شهادة';
      case 'scan':
        return 'أشعة';
      case 'other':
        return 'مرفق';
      default:
        return 'الكل';
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'prescription':
        return Icons.medication_rounded;
      case 'test':
        return Icons.science_rounded;
      case 'certificate':
        return Icons.verified_rounded;
      case 'scan':
        return Icons.document_scanner_rounded;
      case 'other':
        return Icons.attach_file_rounded;
      default:
        return Icons.folder_open_rounded;
    }
  }

  Future<void> _openAddMedicalRecordSheet() async {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إنشاء حساب أولاً')),
      );
      return;
    }

    // ✅ مهم جدًا: نخزن Context بتاع الشاشة (مش بتاع الـ BottomSheet)
    final parentContext = context;

    String selected = 'prescription';
    String? fileDataUrl;
    final titleCtrl = TextEditingController();

    await showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setLocal) {
            final cs = Theme.of(sheetContext).colorScheme;
            final insets = MediaQuery.of(sheetContext).viewInsets.bottom;

            Future<void> pick(ImageSource src) async {
              final data = await _pickImageAsDataUrl(src);
              if (data == null) return;

              // ✅ تأكد إن الـ BottomSheet لسه موجود
              if (!sheetContext.mounted) return;

              setLocal(() => fileDataUrl = data);
            }

            Future<void> upload() async {
              if (fileDataUrl == null) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('اختر المرفق أولاً')),
                );
                return;
              }

              if (!sheetContext.mounted) return;
              setLocal(() => isUploadingRecord = true);

              try {
                final ref = _dbRef
                    .child('users')
                    .child(uid)
                    .child('medicalRecords')
                    .push();

                final now = DateTime.now();
                final defaultTitle =
                    'مرفق طبي - ${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';

                await ref.set({
                  'title': titleCtrl.text.trim().isEmpty
                      ? defaultTitle
                      : titleCtrl.text.trim(),
                  'category': selected,
                  'fileDataUrl': fileDataUrl,
                  'createdAt': ServerValue.timestamp,
                });

                // ✅ اقفل الـ BottomSheet باستخدام sheetContext (ده آمن هنا)
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext);
                }

                // ✅ بعد ما يقفل: رجع حمّل البيانات من الشاشة الأصلية
                if (!mounted) return;
                await _loadMedicalRecords();

                if (!mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('تم إضافة المرفق الطبي ✅'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // ignore: avoid_print
                print('Upload record error: $e');

                if (!parentContext.mounted) return;
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('حدث خطأ أثناء الرفع')),
                );
              } finally {
                if (sheetContext.mounted) {
                  setLocal(() => isUploadingRecord = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: insets),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'إضافة مرفق طبي',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selected,
                      items: const [
                        DropdownMenuItem(
                            value: 'prescription', child: Text('روشتة')),
                        DropdownMenuItem(value: 'test', child: Text('تحليل')),
                        DropdownMenuItem(value: 'scan', child: Text('أشعة')),
                        DropdownMenuItem(
                            value: 'certificate', child: Text('شهادة')),
                        DropdownMenuItem(
                            value: 'other', child: Text('مرفق آخر')),
                      ],
                      onChanged: (v) =>
                          setLocal(() => selected = v ?? selected),
                      decoration: InputDecoration(
                        labelText: 'نوع المرفق',
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        labelText: 'عنوان (اختياري)',
                        hintText: 'مثال: تحليل دم - يناير',
                        prefixIcon: const Icon(Icons.title_rounded),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isUploadingRecord
                                ? null
                                : () => pick(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text(
                              'اختيار من المعرض',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 56,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isUploadingRecord
                                ? null
                                : () => pick(ImageSource.camera),
                            child: const Icon(Icons.camera_alt_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isUploadingRecord ? null : upload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isUploadingRecord
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'إضافة المرفق',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMedicalRecord(String recordId) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('حذف المرفق',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('هل تريد حذف هذا المرفق الطبي؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dbRef
          .child('users')
          .child(uid)
          .child('medicalRecords')
          .child(recordId)
          .remove();

      await _loadMedicalRecords();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المرفق ✅')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الحذف')),
      );
    }
  }

  void _openImagePreview(String dataUrl, String title) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'preview',
      barrierColor: Colors.black.withOpacity(0.92),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 6.0,
                    panEnabled: true,
                    child: Center(
                      child: Image(
                        image: _imageProviderFromDataUrl(dataUrl),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white),
                          tooltip: 'إغلاق',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // ✅ UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final String roleLabel = isGuest
        ? 'زائر'
        : userRole == 'doctor'
            ? 'طبيب'
            : userRole == 'patient'
                ? 'مستخدم'
                : 'مستخدم';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        bottom: false,
        child: isLoadingUser
            ? const _ProfileScreenShimmer()
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    automaticallyImplyLeading: false,
                    elevation: 0,
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    titleSpacing: 20,
                    title: const Text(
                      'حسابي',
                      style: TextStyle(
                        color: Color(0xFF102A2E),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    actions: [
                      if (!isGuest)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: IconButton(
                            tooltip: 'تعديل البيانات',
                            onPressed: _openEditProfileSheet,
                            style: IconButton.styleFrom(
                              backgroundColor: _teal.withOpacity(0.08),
                              foregroundColor: _teal,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 20),
                          ),
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ModernProfileHeader(
                            name: userName,
                            roleLabel: roleLabel,
                            phone: userPhone,
                            imageProvider: _getProfileImageProvider(),
                            teal: _teal,
                            isGuest: isGuest,
                            onEdit: isGuest ? null : _openEditProfileSheet,
                          ),
                          const SizedBox(height: 18),
                          if (isGuest) ...[
                            _GuestAccountCard(
                              teal: _teal,
                              onCreateAccount: _goToCreateAccount,
                            ),
                            const SizedBox(height: 18),
                          ] else ...[
                            const _SectionTitle(
                              title: 'إدارة الحساب',
                              subtitle: 'تحكم في بيانات حسابك وخدماتك',
                            ),
                            const SizedBox(height: 10),
                            _SettingsGroup(
                              children: [
                                _ModernActionTile(
                                  teal: _teal,
                                  icon: Icons.person_outline_rounded,
                                  title: 'البيانات الشخصية',
                                  subtitle: 'تعديل الاسم ورقم الهاتف والصورة',
                                  onTap: _openEditProfileSheet,
                                ),
                                const _SettingsDivider(),
                                if (userRole != 'doctor')
                                  _ModernActionTile(
                                    teal: _teal,
                                    icon: Icons.account_balance_wallet_outlined,
                                    title: 'شحن المحفظة',
                                    subtitle:
                                        'إرسال طلب شحن ومتابعة حالة الرصيد',
                                    onTap: _openTopUpWalletSheet,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (isPatientUser) ...[
                            const _SectionTitle(
                              title: 'السجل الطبي',
                              subtitle:
                                  'احتفظ بروشتاتك وتحاليلك وأشعتك في مكان واحد',
                            ),
                            const SizedBox(height: 10),
                            _MedicalRecordSection(
                              teal: _teal,
                              isUploading: isUploadingRecord,
                              isLoading: isLoadingRecords,
                              selectedCategory: selectedCategory,
                              onCategoryChange: (value) {
                                setState(() => selectedCategory = value);
                              },
                              onAddTap: _openAddMedicalRecordSheet,
                              records: _filteredRecords,
                              onDelete: _deleteMedicalRecord,
                              onOpen: _openImagePreview,
                              imageFromDataUrl: _imageProviderFromDataUrl,
                              categoryLabel: _categoryLabel,
                              categoryIcon: _categoryIcon,
                            ),
                            const SizedBox(height: 18),
                          ],
                          if (!isGuest) ...[
                            const _SectionTitle(
                              title: 'الأمان',
                              subtitle: 'إدارة جلسة تسجيل الدخول الحالية',
                            ),
                            const SizedBox(height: 10),
                            _LogoutCard(onTap: _logout),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =======================
// UI Widgets
// =======================

class _ModernProfileHeader extends StatelessWidget {
  const _ModernProfileHeader({
    required this.name,
    required this.roleLabel,
    required this.phone,
    required this.imageProvider,
    required this.teal,
    required this.isGuest,
    this.onEdit,
  });

  final String name;
  final String roleLabel;
  final String phone;
  final ImageProvider imageProvider;
  final Color teal;
  final bool isGuest;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7EEF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [teal, const Color(0xFF2DD4BF)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: imageProvider,
                      ),
                    ),
                  ),
                  if (onEdit != null)
                    PositionedDirectional(
                      bottom: -2,
                      end: -2,
                      child: InkWell(
                        onTap: onEdit,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: teal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF102A2E),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _SoftBadge(
                          icon: Icons.verified_user_outlined,
                          text: roleLabel,
                          color: teal,
                        ),
                        if (phone.trim().isNotEmpty)
                          _SoftBadge(
                            icon: Icons.phone_outlined,
                            text: phone,
                            color: const Color(0xFF475569),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isGuest ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isGuest
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: isGuest ? const Color(0xFFEA580C) : teal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isGuest
                        ? 'أنشئ حسابًا للاستفادة من جميع المميزات'
                        : 'حسابك جاهز وتستطيع إدارة بياناتك بسهولة',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102A2E),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: Color(0xFFEEF2F4),
    );
  }
}

class _ModernActionTile extends StatelessWidget {
  const _ModernActionTile({
    required this.teal,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color teal;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172B31),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF7A8B92),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFFA6B3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestAccountCard extends StatelessWidget {
  const _GuestAccountCard({
    required this.teal,
    required this.onCreateAccount,
  });

  final Color teal;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            color: Color(0xFF0F766E),
            size: 34,
          ),
          const SizedBox(height: 10),
          const Text(
            'استفد من جميع خدمات سلامتك',
            style: TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'أنشئ حسابًا لحفظ الحجوزات والسجل الطبي والمفضلة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onCreateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'إنشاء حساب',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFED7D7)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'الخروج من الحساب الحالي بأمان',
                      style: TextStyle(
                        color: Color(0xFF9F6B6B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFFE19A9A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileScreenShimmer extends StatelessWidget {
  const _ProfileScreenShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 74, 16, 130),
      children: const [
        _ProfileShimmerBox(height: 190, radius: 26),
        SizedBox(height: 18),
        _ProfileShimmerBox(height: 110, radius: 22),
        SizedBox(height: 18),
        _ProfileShimmerBox(height: 280, radius: 22),
      ],
    );
  }
}

class _ProfileShimmerBox extends StatefulWidget {
  const _ProfileShimmerBox({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  State<_ProfileShimmerBox> createState() => _ProfileShimmerBoxState();
}

class _ProfileShimmerBoxState extends State<_ProfileShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final value = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.4 + (value * 2.8), 0),
              end: Alignment(-0.4 + (value * 2.8), 0),
              colors: const [
                Color(0xFFE8EEF0),
                Color(0xFFF8FAFB),
                Color(0xFFE8EEF0),
              ],
            ).createShader(bounds);
          },
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final Color teal;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.teal,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: cs.onSurface.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final Color primary;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.primary,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// =========================
/// ✅ Medical Records Section
/// =========================
class _MedicalRecordSection extends StatelessWidget {
  final Color teal;

  final bool isUploading;
  final bool isLoading;

  final String selectedCategory;
  final ValueChanged<String> onCategoryChange;

  final VoidCallback onAddTap;

  final List<Map<String, dynamic>> records;
  final Future<void> Function(String recordId) onDelete;

  final void Function(String dataUrl, String title) onOpen;
  final ImageProvider Function(String dataUrl) imageFromDataUrl;

  final String Function(String cat) categoryLabel;
  final IconData Function(String cat) categoryIcon;

  const _MedicalRecordSection({
    required this.teal,
    required this.isUploading,
    required this.isLoading,
    required this.selectedCategory,
    required this.onCategoryChange,
    required this.onAddTap,
    required this.records,
    required this.onDelete,
    required this.onOpen,
    required this.imageFromDataUrl,
    required this.categoryLabel,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.folder_copy_rounded, color: teal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'السجل المرضي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isUploading ? null : onAddTap,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'إضافة',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  active: selectedCategory == 'all',
                  label: 'الكل',
                  teal: teal,
                  onTap: () => onCategoryChange('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  active: selectedCategory == 'prescription',
                  label: 'روشتة',
                  teal: teal,
                  onTap: () => onCategoryChange('prescription'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  active: selectedCategory == 'test',
                  label: 'تحاليل',
                  teal: teal,
                  onTap: () => onCategoryChange('test'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  active: selectedCategory == 'scan',
                  label: 'أشعة',
                  teal: teal,
                  onTap: () => onCategoryChange('scan'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  active: selectedCategory == 'certificate',
                  label: 'شهادة',
                  teal: teal,
                  onTap: () => onCategoryChange('certificate'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  active: selectedCategory == 'other',
                  label: 'مرفقات',
                  teal: teal,
                  onTap: () => onCategoryChange('other'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (isLoading)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
              ),
              child: const Column(
                children: [
                  _MedicalRecordShimmerItem(),
                  SizedBox(height: 10),
                  _MedicalRecordShimmerItem(),
                ],
              ),
            )
          else if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: teal.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: teal),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'لا يوجد أي مرفقات طبية حتى الآن.\nاضغط "إضافة" لرفع روشتة أو تحليل أو أشعة.',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: records.map((r) {
                final id = (r['id'] ?? '').toString();
                final title = (r['title'] ?? 'مرفق طبي').toString();
                final cat = (r['category'] ?? 'other').toString();
                final dataUrl = (r['fileDataUrl'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap:
                          dataUrl.isEmpty ? null : () => onOpen(dataUrl, title),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 62,
                                height: 62,
                                color: cs.surfaceContainerHighest
                                    .withOpacity(0.35),
                                child: dataUrl.isEmpty
                                    ? Icon(Icons.image_not_supported_rounded,
                                        color: cs.onSurface.withOpacity(0.45))
                                    : Image(
                                        image: imageFromDataUrl(dataUrl),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: teal.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: teal.withOpacity(0.20)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(categoryIcon(cat),
                                            size: 16, color: teal),
                                        const SizedBox(width: 6),
                                        Text(
                                          categoryLabel(cat),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: teal,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => onDelete(id),
                              icon: Icon(Icons.delete_rounded, color: cs.error),
                              tooltip: 'حذف',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _MedicalRecordShimmerItem extends StatelessWidget {
  const _MedicalRecordShimmerItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final bool active;
  final String label;
  final Color teal;
  final VoidCallback onTap;

  const _FilterChip({
    required this.active,
    required this.label,
    required this.teal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? teal : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? teal : cs.outlineVariant.withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? Colors.white : cs.onSurface.withOpacity(0.75),
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}
