import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../role/role_selected_screen.dart';

// ==============================
// Theme Colors (Teal)
// ==============================
const Color kTealDark = Color(0xFF0F766E);
const Color kTeal = Color(0xFF14B8A6);
const Color kBg = Color(0xFFF7FAFC);

class DoctorViewPro extends StatefulWidget {
  const DoctorViewPro({super.key});

  @override
  State<DoctorViewPro> createState() => _DoctorViewProState();
}

class _DoctorViewProState extends State<DoctorViewPro> {
  int _selectedIndex = 2;

  bool isLoading = true;

  String doctorName = 'دكتور';
  String doctorSpecialty = '';
  String doctorPhotoUrl = '';
  double rating = 0.0;

  double balance = 0.0; // ✅ رصيد المحفظة فقط
  int todayAppointments = 0;
  int totalPatients = 0;

  List<Map<String, dynamic>> todayAppointmentsList = [];

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();

  String _currentDoctorId() {
    final candidates = <dynamic>[
      _storage.read('userId'),
      _storage.read('doctorId'),
      _storage.read('uid'),
      _storage.read('firebaseUid'),
      _storage.read('doctor_uid'),
      _storage.read('currentUserId'),
    ];

    for (final value in candidates) {
      final id = (value ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  // ✅ فعّلها لو عايز تشوف القيم اللي بتتقرأ
  static const bool kDebugWallet = false;

  @override
  void initState() {
    super.initState();
    _loadCachedDoctorData();
    _loadDoctorDashboard();
  }

  void _loadCachedDoctorData() {
    doctorName = (_storage.read('doctor_cached_name') ?? 'دكتور').toString();
    doctorSpecialty =
        (_storage.read('doctor_cached_specialty') ?? '').toString();
    doctorPhotoUrl = (_storage.read('doctor_cached_photo') ?? '').toString();
    rating = _safeDouble(_storage.read('doctor_cached_rating'), fallback: 0.0);
    balance =
        _safeDouble(_storage.read('doctor_cached_balance'), fallback: 0.0);

    if (doctorName != 'دكتور' || doctorSpecialty.isNotEmpty) {
      isLoading = false;
    }
  }

  // ✅ تاريخ اليوم بصيغة yyyy-MM-dd
  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _safeInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  double _safeDouble(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  // ==========================
  // ✅ Payment Helpers (محفظة فقط)
  // ==========================
  String _norm(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return '';
    return s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), '');
  }

  String _pickString(Map data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  Map<String, dynamic>? _pickMap(Map data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return null;
  }

  bool _isConfirmedStatus(String statusRaw) {
    final s = _norm(statusRaw);
    return s == 'confirmed' ||
        s == 'confirm' ||
        s == 'accepted' ||
        s == 'approve' ||
        s == 'approved';
  }

  bool _isWalletPayment(String methodRaw) {
    final m = _norm(methodRaw);

    // عربي + انجليزي + variants
    if (m.contains('محفظ')) return true;
    if (m == 'wallet') return true;
    if (m.contains('e-wallet') || m.contains('ewallet')) return true;

    return false;
  }

  // ✅ NEW: حالات دفع فاشلة نستبعدها من رصيد المحفظة
  bool _isFailedPaymentStatus(String statusRaw) {
    final s = _norm(statusRaw);
    if (s.isEmpty) return false;

    return s == 'failed' ||
        s == 'fail' ||
        s == 'error' ||
        s == 'canceled' ||
        s == 'cancelled' ||
        s == 'declined' ||
        s == 'rejected' ||
        s == 'void';
  }

  // ✅ استخراج طريقة الدفع من أكتر من مصدر (عشان قيمك "عياده/محفظه")
  String _extractPaymentMethod(Map appData) {
    // 1) nested maps
    final paymentMap = _pickMap(appData, [
      'payment',
      'paymentInfo',
      'paymentData',
      'pay',
      'paymob',
      'transaction',
    ]);

    final fromNested = (paymentMap?['method'] ??
            paymentMap?['type'] ??
            paymentMap?['paymentMethod'] ??
            paymentMap?['paymentType'] ??
            paymentMap?['place'] ??
            paymentMap?['from'] ??
            paymentMap?['source'] ??
            '')
        .toString()
        .trim();

    if (fromNested.isNotEmpty) return fromNested;

    // 2) direct keys (أهم جزء عندك غالبًا)
    return _pickString(appData, [
      // common
      'paymentMethod',
      'paymentType',
      'payMethod',
      'payType',
      'method',
      'type',

      // Arabic-ish keys you may have
      'paymentPlace',
      'paymentFrom',
      'paidFrom',
      'paidIn',
      'payFrom',
      'payIn',
      'paymentWay',
      'payWay',
      'payment_way',
      'pay_way',

      // Sometimes used
      'paymentChannel',
      'channel',
      'source',
      'paySource',
    ]);
  }

  String _extractPaymentStatus(Map appData) {
    final paymentMap = _pickMap(appData, [
      'payment',
      'paymentInfo',
      'paymentData',
      'pay',
      'paymob',
      'transaction',
    ]);

    final fromNested = (paymentMap?['status'] ??
            paymentMap?['paymentStatus'] ??
            paymentMap?['state'] ??
            paymentMap?['result'] ??
            '')
        .toString()
        .trim();

    if (fromNested.isNotEmpty) return fromNested;

    return _pickString(appData, [
      'paymentStatus',
      'payStatus',
      'statusPayment',
      'payment_state',
      'paidStatus',
      'transactionStatus',
    ]);
  }

  // ✅ تحميل بيانات الدكتور + مواعيده + الرصيد (رصيد المحفظة فقط)
  Future<void> _loadDoctorDashboard() async {
    if (!mounted) return;

    // لا نغطي الشاشة كلها بالتحميل بعد أول فتح.
    if (doctorName == 'دكتور' && todayAppointmentsList.isEmpty) {
      setState(() => isLoading = true);
    }

    try {
      final String doctorId = _currentDoctorId();
      if (doctorId.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final results = await Future.wait([
        _dbRef.child('users').child(doctorId).get(),
        _dbRef.child('doctors').child(doctorId).get(),
        _dbRef
            .child('dashboardAppointments')
            .orderByChild('doctorId')
            .equalTo(doctorId)
            .get(),
      ]);

      final userSnap = results[0];
      final doctorNodeSnap = results[1];
      DataSnapshot appointmentsSnap = results[2];

      Map<dynamic, dynamic> d = <dynamic, dynamic>{};
      if (userSnap.exists && userSnap.value is Map) {
        d = Map<dynamic, dynamic>.from(userSnap.value as Map);
      } else if (doctorNodeSnap.exists && doctorNodeSnap.value is Map) {
        d = Map<dynamic, dynamic>.from(doctorNodeSnap.value as Map);
      }

      if (d.isNotEmpty) {
        doctorName = (d['name'] ??
                d['fullName'] ??
                d['doctorName'] ??
                d['displayName'] ??
                'دكتور')
            .toString()
            .trim();
        doctorSpecialty =
            (d['specialization'] ?? d['specialty'] ?? d['speciality'] ?? '')
                .toString()
                .trim();
        doctorPhotoUrl = (d['photoUrl'] ??
                d['profileImage'] ??
                d['imageUrl'] ??
                d['image'] ??
                d['avatar'] ??
                '')
            .toString()
            .trim();
        rating = _safeDouble(d['rating'] ?? d['averageRating'], fallback: 0.0);

        final walletRaw = d['wallet'];
        final walletBalance = walletRaw is Map ? walletRaw['balance'] : null;
        balance = _safeDouble(
          d['balance'] ?? d['walletBalance'] ?? walletBalance,
          fallback: 0.0,
        );

        await Future.wait([
          _storage.write('doctor_cached_name', doctorName),
          _storage.write('doctor_cached_specialty', doctorSpecialty),
          _storage.write('doctor_cached_photo', doctorPhotoUrl),
          _storage.write('doctor_cached_rating', rating),
          _storage.write('doctor_cached_balance', balance),
        ]);
      }

      // لو الاستعلام لم يجد نتيجة بسبب اختلاف اسم حقل الطبيب في بيانات قديمة،
      // نقرأ العقدة مرة واحدة ونفلتر محليًا.
      if (!appointmentsSnap.exists || appointmentsSnap.value == null) {
        appointmentsSnap = await _dbRef.child('dashboardAppointments').get();
      }

      int calcPendingCount = 0;
      final todayList = <Map<String, dynamic>>[];
      final uniquePatients = <String>{};

      if (appointmentsSnap.exists && appointmentsSnap.value != null) {
        final apps = Map<dynamic, dynamic>.from(appointmentsSnap.value as Map);

        for (final entry in apps.entries) {
          final appointmentId = entry.key?.toString() ?? '';
          final value = entry.value;
          if (value is! Map) continue;

          final appData = Map<dynamic, dynamic>.from(value);

          final appDoctorId = (appData['doctorId'] ??
                  appData['doctorUid'] ??
                  appData['doctorUID'] ??
                  appData['doctor_id'] ??
                  '')
              .toString()
              .trim();
          if (appDoctorId != doctorId) continue;

          final visibleToDoctor = appData['visibleToDoctor'] == true ||
              appData['adminApproved'] == true;
          if (!visibleToDoctor) continue;

          final status =
              (appData['status'] ?? appData['bookingStatus'] ?? 'pending')
                  .toString()
                  .trim()
                  .toLowerCase();
          final patientId = (appData['patientId'] ?? '').toString().trim();
          if (patientId.isNotEmpty) uniquePatients.add(patientId);

          if (status != 'pending') continue;

          calcPendingCount++;
          todayList.add({
            'id': appointmentId,
            'patientId': patientId,
            'patientName': (appData['patientName'] ?? 'مريض').toString().trim(),
            'date': _pickString(appData, [
              'date',
              'dateIso',
              'selectedDateIso',
              'selectedDate',
              'bookingDate',
            ]),
            'time': _pickString(appData, [
              'time',
              'slot',
              'selectedSlot',
              'timeSlot',
              'bookedSlot',
            ]),
            'status': status,
            'price': _safeInt(
              appData['appointmentPrice'] ?? appData['price'],
              fallback: 0,
            ),
            'paymentMethod': _extractPaymentMethod(appData),
            'paymentStatus': _extractPaymentStatus(appData),
          });
        }
      }

      todayList.sort(
        (a, b) => (a['time'] ?? '').toString().compareTo(
              (b['time'] ?? '').toString(),
            ),
      );

      if (!mounted) return;
      setState(() {
        todayAppointments = calcPendingCount;
        totalPatients = uniquePatients.length;
        todayAppointmentsList = todayList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('DoctorDashboard error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  // ✅ تحديث حالة الموعد (قبول/رفض/إلغاء)
  Future<void> _updateAppointmentStatus({
    required String patientId,
    required String appointmentId,
    required String newStatus,
  }) async {
    try {
      final dashboardRef =
          _dbRef.child('dashboardAppointments').child(appointmentId);
      final dashboardSnap = await dashboardRef.get();

      if (!dashboardSnap.exists || dashboardSnap.value is! Map) {
        throw Exception('Appointment not found in dashboardAppointments');
      }

      final appData = Map<dynamic, dynamic>.from(dashboardSnap.value as Map);

      final resolvedPatientId = patientId.trim().isNotEmpty
          ? patientId.trim()
          : (appData['patientId'] ?? '').toString().trim();

      final doctorId = (appData['doctorId'] ??
              appData['doctorUid'] ??
              appData['doctorUID'] ??
              _currentDoctorId())
          .toString()
          .trim();

      final price = _safeInt(
        appData['appointmentPrice'] ?? appData['price'],
        fallback: 0,
      );
      final paymentMethod = _extractPaymentMethod(appData);
      final paymentStatus = _extractPaymentStatus(appData);
      final isWallet = _isWalletPayment(paymentMethod);
      final isFailedPay = _isFailedPaymentStatus(paymentStatus);
      final alreadyCredited = appData['walletCredited'] == true;

      final updates = <String, dynamic>{
        'status': newStatus,
        'bookingStatus': newStatus,
        'updatedAt': ServerValue.timestamp,
        if (newStatus == 'confirmed') 'confirmedAt': ServerValue.timestamp,
        if (newStatus == 'cancelled') 'cancelledAt': ServerValue.timestamp,
      };

      // المصدر الأساسي الذي يقرأ منه تطبيق الطبيب.
      await dashboardRef.update(updates);

      // حدّث نسخة المريض فقط لو كانت موجودة فعلًا.
      if (resolvedPatientId.isNotEmpty) {
        final patientAppointmentRef = _dbRef
            .child('appointments')
            .child(resolvedPatientId)
            .child(appointmentId);
        final patientSnap = await patientAppointmentRef.get();
        if (patientSnap.exists) {
          await patientAppointmentRef.update(updates);
        }
      }

      if (newStatus == 'confirmed' &&
          doctorId.isNotEmpty &&
          isWallet &&
          !isFailedPay &&
          !alreadyCredited &&
          price > 0) {
        await _dbRef.child('users').child(doctorId).update({
          'balance': ServerValue.increment(price),
        });

        final creditUpdates = <String, dynamic>{
          'walletCredited': true,
          'walletCreditedAt': ServerValue.timestamp,
        };
        await dashboardRef.update(creditUpdates);

        if (resolvedPatientId.isNotEmpty) {
          final patientAppointmentRef = _dbRef
              .child('appointments')
              .child(resolvedPatientId)
              .child(appointmentId);
          final patientSnap = await patientAppointmentRef.get();
          if (patientSnap.exists) {
            await patientAppointmentRef.update(creditUpdates);
          }
        }
      }

      await _loadDoctorDashboard();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الحجز إلى "${_getStatusText(newStatus)}"'),
        ),
      );
    } catch (e) {
      debugPrint('Update status error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث الحالة')),
      );
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد التأكيد';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final doctorId = _currentDoctorId();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const _DoctorDashboardShimmer()
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: _buildSelectedTab(doctorId),
                ),
              ),
      ),
      bottomNavigationBar: _DoctorBottomNav(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        avatar: doctorPhotoUrl,
      ),
    );
  }

  Widget _buildSelectedTab(String doctorId) {
    switch (_selectedIndex) {
      case 0:
        return DoctorAppointmentsTabPro(onChanged: _loadDoctorDashboard);

      case 1:
        return DoctorPatientsTabPro(doctorId: doctorId);

      case 2:
        return RefreshIndicator(
          color: kTealDark,
          onRefresh: _loadDoctorDashboard,
          child: _DoctorHomeTabPro(
            doctorName: doctorName,
            doctorSpecialty: doctorSpecialty,
            doctorPhotoUrl: doctorPhotoUrl,
            balance: balance,
            todayAppointments: todayAppointments,
            totalPatients: totalPatients,
            rating: rating,
            todayAppointmentsList: todayAppointmentsList,
            onAccept: (appointmentId, patientId) {
              _updateAppointmentStatus(
                patientId: patientId,
                appointmentId: appointmentId,
                newStatus: 'confirmed',
              );
            },
            onReject: (appointmentId, patientId) {
              _updateAppointmentStatus(
                patientId: patientId,
                appointmentId: appointmentId,
                newStatus: 'cancelled',
              );
            },
            onCancel: (appointmentId, patientId, status) {
              _updateAppointmentStatus(
                patientId: patientId,
                appointmentId: appointmentId,
                newStatus: 'cancelled',
              );
            },
            statusText: _getStatusText,
            statusColor: _getStatusColor,
          ),
        );

      case 3:
        return DoctorWalletTabPro(
          doctorId: doctorId,
          initialBalance: balance,
          doctorName: doctorName,
        );

      case 4:
        return DoctorProfileTabPro(
          doctorId: doctorId,
          onLogout: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const RoleSelectionScreen(),
              ),
              (_) => false,
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _navItem(IconData icon, String label, int index) =>
      const SizedBox.shrink();
}

class _DoctorBottomNav extends StatelessWidget {
  const _DoctorBottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.avatar,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final String avatar;

  ImageProvider? _avatarProvider() {
    final value = avatar.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(value.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return CachedNetworkImageProvider(value);
  }

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'مواعيدي'),
      (Icons.groups_2_outlined, Icons.groups_2_rounded, 'المرضى'),
      (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        'المحفظة'
      ),
      (Icons.person_outline_rounded, Icons.person_rounded, 'حسابي'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE6ECEE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final selected = selectedIndex == index;
            final item = items[index];

            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 62,
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFFE7F7F5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (index == 4 && _avatarProvider() != null)
                        Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? kTealDark
                                  : const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: _avatarProvider()!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Icon(
                          selected ? item.$2 : item.$1,
                          size: 23,
                          color: selected ? kTealDark : const Color(0xFF94A3B8),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected ? kTealDark : const Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class DoctorPatientsTabPro extends StatefulWidget {
  const DoctorPatientsTabPro({
    super.key,
    required this.doctorId,
  });

  final String doctorId;

  @override
  State<DoctorPatientsTabPro> createState() => _DoctorPatientsTabProState();
}

class _DoctorPatientsTabProState extends State<DoctorPatientsTabPro> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool loading = true;
  String query = '';
  List<Map<String, dynamic>> patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      DataSnapshot snap = await _db
          .child('dashboardAppointments')
          .orderByChild('doctorId')
          .equalTo(widget.doctorId)
          .get();

      if (!snap.exists || snap.value == null) {
        snap = await _db.child('dashboardAppointments').get();
      }

      final Map<String, Map<String, dynamic>> grouped = {};

      if (snap.exists && snap.value is Map) {
        final raw = Map<dynamic, dynamic>.from(snap.value as Map);

        for (final entry in raw.entries) {
          if (entry.value is! Map) continue;
          final data = Map<String, dynamic>.from(
            Map<dynamic, dynamic>.from(entry.value as Map),
          );

          final doctorId = (data['doctorId'] ??
                  data['doctorUid'] ??
                  data['doctorUID'] ??
                  data['doctor_id'] ??
                  '')
              .toString()
              .trim();
          if (doctorId != widget.doctorId) continue;

          final patientId = (data['patientId'] ?? '').toString().trim();
          final patientName = (data['patientName'] ?? 'مريض').toString().trim();
          final key = patientId.isNotEmpty ? patientId : patientName;

          grouped.putIfAbsent(key, () {
            return {
              'patientId': patientId,
              'name': patientName,
              'phone': (data['patientPhone'] ?? '').toString(),
              'photoUrl': (data['patientPhotoUrl'] ??
                      data['patientImage'] ??
                      data['patientAvatar'] ??
                      '')
                  .toString(),
              'appointments': <Map<String, dynamic>>[],
              'totalVisits': 0,
              'confirmedVisits': 0,
              'lastDate': '',
            };
          });

          final patient = grouped[key]!;
          final appointments =
              patient['appointments'] as List<Map<String, dynamic>>;
          appointments.add({
            'id': entry.key.toString(),
            'date': (data['date'] ??
                    data['dateIso'] ??
                    data['selectedDateIso'] ??
                    data['bookingDate'] ??
                    '')
                .toString(),
            'time': (data['time'] ??
                    data['slot'] ??
                    data['selectedSlot'] ??
                    data['timeSlot'] ??
                    '')
                .toString(),
            'status': (data['status'] ?? data['bookingStatus'] ?? 'pending')
                .toString(),
            'price': data['appointmentPrice'] ?? data['price'] ?? 0,
          });

          patient['totalVisits'] = (patient['totalVisits'] as int) + 1;
          final status =
              (data['status'] ?? data['bookingStatus'] ?? '').toString();
          if (status == 'confirmed') {
            patient['confirmedVisits'] =
                (patient['confirmedVisits'] as int) + 1;
          }

          final date = (data['date'] ??
                  data['dateIso'] ??
                  data['selectedDateIso'] ??
                  data['bookingDate'] ??
                  '')
              .toString();
          if (date.compareTo((patient['lastDate'] ?? '').toString()) > 0) {
            patient['lastDate'] = date;
          }
        }
      }

      final result = grouped.values.toList()
        ..sort((a, b) => (b['lastDate'] ?? '')
            .toString()
            .compareTo((a['lastDate'] ?? '').toString()));

      final ids = result
          .map((e) => (e['patientId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      await Future.wait(ids.map((id) async {
        final userSnap = await _db.child('users').child(id).get();
        if (!userSnap.exists || userSnap.value is! Map) return;

        final data = Map<dynamic, dynamic>.from(userSnap.value as Map);
        final patient = result.firstWhere(
          (p) => (p['patientId'] ?? '').toString() == id,
        );

        final actualName = (data['name'] ?? data['fullName'] ?? '').toString();
        final actualPhone = (data['phone'] ?? '').toString();
        final actualPhoto =
            (data['photoUrl'] ?? data['profileImage'] ?? '').toString();

        if (actualName.trim().isNotEmpty) patient['name'] = actualName;
        if (actualPhone.trim().isNotEmpty) patient['phone'] = actualPhone;
        if (actualPhoto.trim().isNotEmpty) patient['photoUrl'] = actualPhoto;
      }));

      if (!mounted) return;
      setState(() {
        patients = result;
        loading = false;
      });
    } catch (e) {
      debugPrint('Doctor patients error: $e');
      if (!mounted) return;
      setState(() {
        patients = [];
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visiblePatients {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return patients;
    return patients.where((patient) {
      final name = (patient['name'] ?? '').toString().toLowerCase();
      final phone = (patient['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  ImageProvider? _imageProvider(String value) {
    final url = value.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return CachedNetworkImageProvider(url);
  }

  void _openPatientFile(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DoctorPatientFileScreen(
          patient: patient,
          imageProvider: _imageProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePatients;

    return RefreshIndicator(
      color: kTealDark,
      onRefresh: _loadPatients,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مرضاي',
                    style: TextStyle(
                      color: Color(0xFF102A2E),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${patients.length} ملف مريض مرتبط بحجوزاتك',
                    style: const TextStyle(
                      color: Color(0xFF71838A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو رقم الهاتف',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: kTealDark,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE3EAEC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE3EAEC)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _DoctorPatientsLoading(),
              ),
            )
          else if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 30, 16, 140),
                child: _DoctorModernEmptyState(
                  title: 'لا يوجد مرضى حتى الآن',
                  subtitle: 'سيظهر هنا كل مريض لديه حجز مرتبط بحسابك.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final patient = visible[index];
                  return _DoctorPatientCard(
                    patient: patient,
                    imageProvider:
                        _imageProvider((patient['photoUrl'] ?? '').toString()),
                    onTap: () => _openPatientFile(patient),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DoctorPatientFileScreen extends StatelessWidget {
  const _DoctorPatientFileScreen({
    required this.patient,
    required this.imageProvider,
  });

  final Map<String, dynamic> patient;
  final ImageProvider? Function(String value) imageProvider;

  @override
  Widget build(BuildContext context) {
    final appointments =
        List<Map<String, dynamic>>.from(patient['appointments'] ?? const []);
    final photo = imageProvider((patient['photoUrl'] ?? '').toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF102A2E),
        elevation: 0,
        title: const Text(
          'ملف المريض',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3EAEC)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE8F7F5),
                  backgroundImage: photo,
                  child: photo == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: kTealDark,
                          size: 34,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (patient['name'] ?? 'مريض').toString(),
                        style: const TextStyle(
                          color: Color(0xFF102A2E),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (patient['phone'] ?? 'رقم الهاتف غير متوفر').toString(),
                        style: const TextStyle(
                          color: Color(0xFF71838A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PatientFileMetric(
                  title: 'إجمالي الحجوزات',
                  value: '${patient['totalVisits'] ?? 0}',
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PatientFileMetric(
                  title: 'حجوزات مؤكدة',
                  value: '${patient['confirmedVisits'] ?? 0}',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'سجل الحجوزات',
            style: TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...appointments.map(
            (a) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5ECEE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F6),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: kTealDark,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (a['date'] ?? 'تاريخ غير محدد').toString(),
                          style: const TextStyle(
                            color: Color(0xFF102A2E),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${a['time'] ?? 'وقت غير محدد'} • ${a['status'] ?? ''}',
                          style: const TextStyle(
                            color: Color(0xFF71838A),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorWalletTabPro extends StatefulWidget {
  const DoctorWalletTabPro({
    super.key,
    required this.doctorId,
    required this.initialBalance,
    required this.doctorName,
  });

  final String doctorId;
  final double initialBalance;
  final String doctorName;

  @override
  State<DoctorWalletTabPro> createState() => _DoctorWalletTabProState();
}

class _DoctorWalletTabProState extends State<DoctorWalletTabPro> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool loading = true;
  double balance = 0;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    balance = widget.initialBalance;
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final results = await Future.wait([
        _db.child('users').child(widget.doctorId).get(),
        _db.child('adminWithdrawalRequests').get(),
      ]);

      final userSnap = results[0];
      final reqSnap = results[1];

      if (userSnap.exists && userSnap.value is Map) {
        final data = Map<dynamic, dynamic>.from(userSnap.value as Map);
        final wallet = data['wallet'];
        final nested = wallet is Map ? wallet['balance'] : null;
        balance = double.tryParse(
              '${data['balance'] ?? data['walletBalance'] ?? nested ?? 0}',
            ) ??
            0;
      }

      final list = <Map<String, dynamic>>[];
      if (reqSnap.exists && reqSnap.value is Map) {
        final raw = Map<dynamic, dynamic>.from(reqSnap.value as Map);
        for (final entry in raw.entries) {
          if (entry.value is! Map) continue;
          final data = Map<dynamic, dynamic>.from(entry.value as Map);
          final requestDoctorId =
              (data['doctorId'] ?? data['doctorUid'] ?? '').toString();
          final requestDoctorName = (data['doctorName'] ?? '').toString();

          if (requestDoctorId == widget.doctorId ||
              (requestDoctorId.isEmpty &&
                  requestDoctorName == widget.doctorName)) {
            list.add({
              'id': entry.key.toString(),
              'amount': data['amount'] ?? 0,
              'status': data['status'] ?? 'pending',
              'createdAt': data['createdAt'] ?? 0,
            });
          }
        }
      }

      list.sort((a, b) => (int.tryParse('${b['createdAt']}') ?? 0).compareTo(
            int.tryParse('${a['createdAt']}') ?? 0,
          ));

      if (!mounted) return;
      setState(() {
        requests = list;
        loading = false;
      });
    } catch (e) {
      debugPrint('Wallet tab error: $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _requestWithdraw() async {
    if (balance <= 0) return;

    final controller = TextEditingController(text: balance.toStringAsFixed(0));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'سحب من المحفظة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المطلوب',
                    filled: true,
                    fillColor: const Color(0xFFF7FAFB),
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
                    onPressed: () async {
                      final amount =
                          double.tryParse(controller.text.trim()) ?? 0;
                      if (amount <= 0 || amount > balance) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('المبلغ غير صحيح')),
                        );
                        return;
                      }

                      final ref = _db.child('adminWithdrawalRequests').push();
                      await ref.set({
                        'requestId': ref.key,
                        'doctorId': widget.doctorId,
                        'doctorName': widget.doctorName,
                        'amount': amount,
                        'status': 'pending',
                        'createdAt': ServerValue.timestamp,
                      });

                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      await _loadWallet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'إرسال الطلب',
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
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kTealDark,
      onRefresh: _loadWallet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 140),
        children: [
          const Text(
            'المحفظة',
            style: TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'رصيدك وطلبات السحب في مكان واحد',
            style: TextStyle(
              color: Color(0xFF71838A),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: kTealDark.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرصيد المتاح',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${balance.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: balance <= 0 ? null : _requestWithdraw,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kTealDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'طلب سحب',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'طلبات السحب',
            style: TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const _DoctorPatientsLoading()
          else if (requests.isEmpty)
            const _DoctorModernEmptyState(
              title: 'لا توجد طلبات سحب',
              subtitle: 'عند إرسال طلب سحب سيظهر هنا ويمكنك متابعة حالته.',
            )
          else
            ...requests.map((request) {
              final status = (request['status'] ?? 'pending').toString();
              final color = status == 'approved'
                  ? const Color(0xFF16A34A)
                  : status == 'rejected'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF59E0B);
              final label = status == 'approved'
                  ? 'تم التحويل'
                  : status == 'rejected'
                      ? 'مرفوض'
                      : 'قيد المراجعة';

              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5ECEE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        '${request['amount']} جنيه',
                        style: const TextStyle(
                          color: Color(0xFF102A2E),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _DoctorWalletHero extends StatelessWidget {
  const _DoctorWalletHero({
    required this.balance,
    required this.rating,
    required this.onWithdraw,
  });

  final double balance;
  final double rating;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: kTealDark.withOpacity(0.18),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رصيد المحفظة',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${balance.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD166),
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} تقييم الحساب',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onWithdraw,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'سحب الرصيد',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorMetricCard extends StatelessWidget {
  const _DoctorMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE6ECEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7A8B92),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3EAEC)),
        ),
        child: const Icon(
          Icons.support_agent_rounded,
          color: kTealDark,
          size: 21,
        ),
      ),
    );
  }
}

class _DoctorRequestCard extends StatelessWidget {
  const _DoctorRequestCard({
    required this.patientName,
    required this.time,
    required this.date,
    required this.price,
    required this.statusText,
    required this.statusColor,
    this.onAccept,
    this.onReject,
  });

  final String patientName;
  final String time;
  final String date;
  final String price;
  final String statusText;
  final Color statusColor;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EBED)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: kTealDark,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        color: Color(0xFF102A2E),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.isEmpty ? 'تاريخ غير محدد' : date} • ${time.isEmpty ? 'وقت غير محدد' : time}',
                      style: const TextStyle(
                        color: Color(0xFF71838A),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 17,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                '$price جنيه',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onReject != null)
                TextButton(
                  onPressed: onReject,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text(
                    'رفض',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              if (onAccept != null) ...[
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'قبول',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DoctorModernEmptyState extends StatelessWidget {
  const _DoctorModernEmptyState({
    this.title = 'لا توجد طلبات جديدة',
    this.subtitle = 'عند وصول طلب حجز جديد سيظهر هنا مباشرة.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5ECEE)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_outlined,
              color: kTealDark,
              size: 29,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF71838A),
              fontSize: 10.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorPatientCard extends StatelessWidget {
  const _DoctorPatientCard({
    required this.patient,
    required this.imageProvider,
    required this.onTap,
  });

  final Map<String, dynamic> patient;
  final ImageProvider? imageProvider;
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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EBED)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFFEAF8F6),
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? const Icon(Icons.person_rounded, color: kTealDark)
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (patient['name'] ?? 'مريض').toString(),
                      style: const TextStyle(
                        color: Color(0xFF102A2E),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (patient['phone'] ?? 'رقم الهاتف غير متوفر').toString(),
                      style: const TextStyle(
                        color: Color(0xFF71838A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${patient['totalVisits'] ?? 0} حجز • ${patient['confirmedVisits'] ?? 0} مؤكد',
                      style: const TextStyle(
                        color: kTealDark,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientFileMetric extends StatelessWidget {
  const _PatientFileMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EBED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kTealDark, size: 20),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102A2E),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF71838A),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorPatientsLoading extends StatelessWidget {
  const _DoctorPatientsLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          height: 82,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF0),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

// ==============================
// ✅ Doctor Home UI (Slivers)
// ==============================
class _DoctorHomeTabPro extends StatelessWidget {
  final String doctorName;
  final String doctorSpecialty;
  final String doctorPhotoUrl;

  final double balance;
  final int todayAppointments;
  final int totalPatients;
  final double rating;

  final List<Map<String, dynamic>> todayAppointmentsList;

  final void Function(String appointmentId, String patientId) onAccept;
  final void Function(String appointmentId, String patientId) onReject;
  final void Function(String appointmentId, String patientId, String status)
      onCancel;

  final String Function(String status) statusText;
  final Color Function(String status) statusColor;

  const _DoctorHomeTabPro({
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorPhotoUrl,
    required this.balance,
    required this.todayAppointments,
    required this.totalPatients,
    required this.rating,
    required this.todayAppointmentsList,
    required this.onAccept,
    required this.onReject,
    required this.onCancel,
    required this.statusText,
    required this.statusColor,
  });
  Future<void> requestWithdraw(
    BuildContext context,
    double amount,
  ) async {
    try {
      final db = FirebaseDatabase.instance.ref();

      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      final requestData = {
        'requestId': requestId,
        'doctorName': doctorName,
        'amount': amount,
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
      };

      await db
          .child('adminWithdrawalRequests')
          .child(requestId)
          .set(requestData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال طلب السحب'),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  ImageProvider _doctorImage() {
    if (doctorPhotoUrl.startsWith('data:image')) {
      try {
        final String b64 = doctorPhotoUrl.split(',').last;
        final Uint8List bytes = base64Decode(b64);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    if (doctorPhotoUrl.isNotEmpty) {
      return CachedNetworkImageProvider(doctorPhotoUrl);
    }

    return const AssetImage('assets/images/jj.jpg');
  }

  Future<void> _openSupport(BuildContext context) async {
    const phone = '201080505068';
    const message =
        'مرحبًا، أنا طبيب في تطبيق سلامتك وأحتاج إلى دعم فني من فضلك.';

    final appUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final opened = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showWithdrawSheet(BuildContext context) async {
    final amountController = TextEditingController(
      text: balance > 0 ? balance.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلب سحب الرصيد',
                  style: TextStyle(
                    color: Color(0xFF102A2E),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الرصيد المتاح ${balance.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(
                    color: Color(0xFF71838A),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: kTealDark,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0 || amount > balance) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content:
                                Text('أدخل مبلغًا صحيحًا داخل رصيدك المتاح'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(sheetContext);
                      await requestWithdraw(context, amount);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'إرسال طلب السحب',
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

    amountController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = todayAppointmentsList
        .where((item) => (item['status'] ?? '').toString() == 'pending')
        .length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFFF4F7F8),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFE5F8F5),
                      backgroundImage: _doctorImage(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً د. $doctorName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF102A2E),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            doctorSpecialty.isEmpty
                                ? 'حساب الطبيب'
                                : doctorSpecialty,
                            style: const TextStyle(
                              color: Color(0xFF72858B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SupportButton(onTap: () => _openSupport(context)),
                  ],
                ),
                const SizedBox(height: 18),
                _DoctorWalletHero(
                  balance: balance,
                  rating: rating,
                  onWithdraw:
                      balance <= 0 ? null : () => _showWithdrawSheet(context),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DoctorMetricCard(
                        title: 'طلبات جديدة',
                        value: pendingCount.toString(),
                        icon: Icons.notifications_active_outlined,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DoctorMetricCard(
                        title: 'المرضى',
                        value: totalPatients.toString(),
                        icon: Icons.groups_2_outlined,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DoctorMetricCard(
                        title: 'التقييم',
                        value: rating.toStringAsFixed(1),
                        icon: Icons.star_outline_rounded,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الطلبات القادمة',
                            style: TextStyle(
                              color: Color(0xFF102A2E),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'راجع الطلب ثم قم بالقبول أو الرفض',
                            style: TextStyle(
                              color: Color(0xFF7A8B92),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$pendingCount طلب',
                        style: const TextStyle(
                          color: kTealDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
              ],
            ),
          ),
        ),
        if (todayAppointmentsList.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 140),
              child: _DoctorModernEmptyState(),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
            sliver: SliverList.separated(
              itemCount: todayAppointmentsList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final a = todayAppointmentsList[index];
                final status = (a['status'] ?? 'pending').toString();

                return _DoctorRequestCard(
                  patientName: (a['patientName'] ?? 'مريض').toString(),
                  time: (a['time'] ?? '').toString(),
                  date: (a['date'] ?? '').toString(),
                  price: (a['price'] ?? 0).toString(),
                  statusText: statusText(status),
                  statusColor: statusColor(status),
                  onAccept: status == 'pending'
                      ? () => onAccept(
                            (a['id'] ?? '').toString(),
                            (a['patientId'] ?? '').toString(),
                          )
                      : null,
                  onReject: status == 'pending'
                      ? () => onReject(
                            (a['id'] ?? '').toString(),
                            (a['patientId'] ?? '').toString(),
                          )
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

// ==============================
// ✅ Helpers بسيطة (لو عندك موجودين سيبهم)
// ==============================
class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: kTeal.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: kTealDark.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -8,
            bottom: -10,
            child: Icon(
              icon,
              size: 72,
              color: kTeal.withOpacity(0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kTeal.withOpacity(0.18),
                      kTealDark.withOpacity(0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: kTealDark,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: kTealDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ⚠️ ده placeholder لو عندك كارت المواعيد الحقيقي سيبه زي ما هو عندك
class _AppointmentCardPro extends StatelessWidget {
  final String patientName;
  final String time;
  final String price;
  final String statusText;
  final Color statusColor;
  final String statusRaw;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _AppointmentCardPro({
    required this.patientName,
    required this.time,
    required this.price,
    required this.statusText,
    required this.statusColor,
    required this.statusRaw,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  patientName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 18),
              const SizedBox(width: 6),
              Text(time.isEmpty ? 'غير محدد' : time,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              const Icon(Icons.payments_rounded, size: 18),
              const SizedBox(width: 6),
              Text('$price جنيه',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          if (onAccept != null || onReject != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onAccept != null)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'قبول ✅',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (onAccept != null && onReject != null)
                  const SizedBox(width: 10),
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'رفض ❌',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                if (onCancel != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade700),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ==============================
// ✅ Doctor Appointments Tab (All Appointments) - ExpansionTile
// ==============================

class DoctorAppointmentsTabPro extends StatefulWidget {
  final Future<void> Function() onChanged;

  const DoctorAppointmentsTabPro({super.key, required this.onChanged});

  @override
  State<DoctorAppointmentsTabPro> createState() =>
      _DoctorAppointmentsTabProState();
}

class _DoctorAppointmentsTabProState extends State<DoctorAppointmentsTabPro>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();

  String _currentDoctorId() {
    final candidates = <dynamic>[
      _storage.read('userId'),
      _storage.read('doctorId'),
      _storage.read('uid'),
      _storage.read('firebaseUid'),
      _storage.read('doctor_uid'),
      _storage.read('currentUserId'),
    ];
    for (final value in candidates) {
      final id = (value ?? '').toString().trim();
      if (id.isNotEmpty) return id;
    }
    return '';
  }

  bool isLoading = true;
  List<Map<String, dynamic>> allAppointments = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _safeInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  String _pickString(Map data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is Map) continue;

      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  String _formatArabicDay(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    if (t.contains('ال') || t.contains('سبت') || t.contains('أحد')) return t;
    return t;
  }

  String _formatDateWithDayFromAny(String dateRaw, String dayRaw) {
    final day = _formatArabicDay(dayRaw);
    final raw = dateRaw.trim();

    final dt = DateTime.tryParse(raw);
    if (dt != null) {
      final dateText = DateFormat('dd/MM/yyyy').format(dt);
      final dayText = DateFormat('EEEE', 'ar').format(dt);
      return '$dayText • $dateText';
    }

    if (raw.isNotEmpty && day.isNotEmpty) return '$day • $raw';
    if (raw.isNotEmpty) return raw;
    if (day.isNotEmpty) return day;
    return 'غير محدد';
  }

  ImageProvider _patientImageProvider(String url) {
    final u = url.trim();
    if (u.isEmpty) return const AssetImage('assets/images/logo.jpeg');
    if (u.startsWith('http')) return NetworkImage(u);
    return const AssetImage('assets/images/logo.jpeg');
  }

  String _paymentText(String s) {
    switch (s) {
      case 'paid':
        return 'مدفوع';
      case 'pending':
        return 'قيد المراجعة';
      case 'failed':
        return 'فشل الدفع';
      case 'refund':
        return 'مسترجع';
      case 'cash':
        return 'كاش عند الزيارة';
      case 'unpaid':
      default:
        return 'غير مدفوع';
    }
  }

  Color _paymentColor(String s) {
    switch (s) {
      case 'paid':
        return Colors.green.shade700;
      case 'pending':
        return Colors.orange.shade700;
      case 'failed':
        return Colors.red.shade700;
      case 'refund':
        return Colors.blueGrey.shade700;
      case 'cash':
        return Colors.teal.shade700;
      case 'unpaid':
      default:
        return Colors.grey.shade700;
    }
  }

  String _paymentMethodText(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return '';
    switch (t) {
      case 'card':
        return 'بطاقة';
      case 'wallet':
        return 'محفظة';
      case 'clinic':
        return 'عيادة';
      case 'cash':
        return 'كاش';
      default:
        return s;
    }
  }

  String _formatPaidAt(int ms) {
    if (ms <= 0) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      return DateFormat('dd/MM • hh:mm a', 'ar').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadAllAppointments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final String doctorId = _currentDoctorId();

      if (doctorId.isEmpty) {
        if (!mounted) return;
        setState(() {
          allAppointments = [];
          isLoading = false;
        });
        return;
      }

      DataSnapshot snapshot = await _dbRef
          .child('dashboardAppointments')
          .orderByChild('doctorId')
          .equalTo(doctorId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        snapshot = await _dbRef.child('dashboardAppointments').get();
      }

      final List<Map<String, dynamic>> list = [];

      if (snapshot.exists && snapshot.value != null) {
        final apps = Map<dynamic, dynamic>.from(snapshot.value as Map);

        for (final entry in apps.entries) {
          final appointmentId = entry.key?.toString() ?? '';
          final value = entry.value;
          if (value is! Map) continue;

          final appData = Map<dynamic, dynamic>.from(value);

          final appDoctorId = (appData['doctorId'] ??
                  appData['doctorUid'] ??
                  appData['doctorUID'] ??
                  appData['doctor_id'] ??
                  '')
              .toString()
              .trim();
          if (appDoctorId != doctorId) continue;

          final visibleToDoctor = appData['visibleToDoctor'] == true ||
              appData['adminApproved'] == true;
          if (!visibleToDoctor) continue;

          final String status =
              (appData['status'] ?? appData['bookingStatus'] ?? 'pending')
                  .toString()
                  .trim()
                  .toLowerCase();
          final String patientName =
              (appData['patientName'] ?? 'مريض').toString().trim();
          final String patientPhone =
              (appData['patientPhone'] ?? 'غير متوفر').toString().trim();

          final String dateRaw = _pickString(appData, [
            'date',
            'dateIso',
            'selectedDateIso',
            'selectedDate',
            'bookingDate',
          ]);
          final String dayRaw = _pickString(appData, [
            'day',
            'selectedDay',
            'bookingDay',
          ]);
          final String bookedSlot = _pickString(appData, [
            'selectedSlot',
            'slot',
            'timeSlot',
            'bookedSlot',
            'time',
          ]);

          final String patientPhotoUrl = _pickString(appData, [
            'patientPhotoUrl',
            'patientImage',
            'patientAvatar',
            'photoUrl',
          ]);

          final String paymentStatusRaw = _pickString(appData, [
            'paymentStatus',
            'payStatus',
            'payment_state',
          ]);

          list.add({
            'id': appointmentId,
            'patientId': (appData['patientId'] ?? '').toString(),
            'patientName': patientName,
            'patientPhone': patientPhone,
            'dateRaw': dateRaw,
            'dayRaw': dayRaw,
            'dateText': _formatDateWithDayFromAny(dateRaw, dayRaw),
            'slot': bookedSlot.isEmpty ? 'غير محدد' : bookedSlot,
            'status': status,
            'price': _safeInt(
              appData['appointmentPrice'] ?? appData['price'],
              fallback: 300,
            ),
            'patientPhotoUrl': patientPhotoUrl,
            'paymentStatus': paymentStatusRaw.isEmpty
                ? 'unpaid'
                : paymentStatusRaw.toLowerCase(),
            'paymentMethod': _pickString(appData, [
              'paymentMethod',
              'paymentType',
              'payMethod',
              'method',
            ]),
            'paidAt': _safeInt(
              appData['paidAt'] ?? appData['paymentAt'],
              fallback: 0,
            ),
          });
        }
      }

      list.sort((a, b) {
        final da = DateTime.tryParse((a['dateRaw'] ?? '').toString());
        final db = DateTime.tryParse((b['dateRaw'] ?? '').toString());
        if (da != null && db != null) {
          final result = db.compareTo(da);
          if (result != 0) return result;
        }
        return (b['slot'] ?? '')
            .toString()
            .compareTo((a['slot'] ?? '').toString());
      });

      if (!mounted) return;
      setState(() {
        allAppointments = list;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ جلب مواعيد الطبيب: $e');
      if (!mounted) return;
      setState(() {
        allAppointments = [];
        isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'confirmed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _updateAppointmentStatus({
    required String patientId,
    required String appointmentId,
    required String newStatus,
  }) async {
    try {
      final dashboardRef =
          _dbRef.child('dashboardAppointments').child(appointmentId);
      final dashboardSnap = await dashboardRef.get();

      if (!dashboardSnap.exists || dashboardSnap.value is! Map) {
        throw Exception('Appointment not found in dashboardAppointments');
      }

      final appData = Map<dynamic, dynamic>.from(dashboardSnap.value as Map);
      final resolvedPatientId = patientId.trim().isNotEmpty
          ? patientId.trim()
          : (appData['patientId'] ?? '').toString().trim();

      final updates = <String, dynamic>{
        'status': newStatus,
        'bookingStatus': newStatus,
        'updatedAt': ServerValue.timestamp,
        if (newStatus == 'confirmed') 'confirmedAt': ServerValue.timestamp,
        if (newStatus == 'cancelled') 'cancelledAt': ServerValue.timestamp,
      };

      await dashboardRef.update(updates);

      if (resolvedPatientId.isNotEmpty) {
        final patientAppointmentRef = _dbRef
            .child('appointments')
            .child(resolvedPatientId)
            .child(appointmentId);
        final patientSnap = await patientAppointmentRef.get();
        if (patientSnap.exists) {
          await patientAppointmentRef.update(updates);
        }
      }

      // إضافة قيمة الحجز للمحفظة مرة واحدة عند القبول من صفحة مواعيدي.
      if (newStatus == 'confirmed' && appData['walletCredited'] != true) {
        final doctorId = (appData['doctorId'] ??
                appData['doctorUid'] ??
                appData['doctorUID'] ??
                _currentDoctorId())
            .toString()
            .trim();
        final price = _safeInt(
          appData['appointmentPrice'] ?? appData['price'],
          fallback: 0,
        );
        final paymentMethod = (appData['paymentMethod'] ??
                appData['paymentType'] ??
                appData['payMethod'] ??
                appData['method'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
        final paymentStatus = (appData['paymentStatus'] ??
                appData['payStatus'] ??
                appData['payment_state'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

        final isWallet = paymentMethod == 'wallet' ||
            paymentMethod.contains('محفظ') ||
            paymentMethod.contains('ewallet') ||
            paymentMethod.contains('e-wallet');
        final isFailed = const {
          'failed',
          'fail',
          'error',
          'canceled',
          'cancelled',
          'declined',
          'rejected',
          'void',
        }.contains(paymentStatus);

        if (doctorId.isNotEmpty && isWallet && !isFailed && price > 0) {
          await _dbRef.child('users').child(doctorId).update({
            'balance': ServerValue.increment(price),
          });

          final creditUpdates = <String, dynamic>{
            'walletCredited': true,
            'walletCreditedAt': ServerValue.timestamp,
          };
          await dashboardRef.update(creditUpdates);

          if (resolvedPatientId.isNotEmpty) {
            final patientAppointmentRef = _dbRef
                .child('appointments')
                .child(resolvedPatientId)
                .child(appointmentId);
            final patientSnap = await patientAppointmentRef.get();
            if (patientSnap.exists) {
              await patientAppointmentRef.update(creditUpdates);
            }
          }
        }
      }

      await _loadAllAppointments();
      await widget.onChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: newStatus == 'confirmed'
              ? Colors.green.shade700
              : Colors.red.shade700,
          content: Text('تم تحديث الحجز إلى "${_getStatusText(newStatus)}"'),
        ),
      );
    } catch (e) {
      debugPrint('خطأ تحديث الحجز: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل تحديث الحجز')),
      );
    }
  }

  List<Map<String, dynamic>> _filterByStatus(String status) {
    return allAppointments
        .where((a) => (a['status'] ?? 'pending').toString() == status)
        .toList();
  }

  Widget _buildCounterChip({
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$title $count',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return _EmptyAppointmentState(
        title: 'لا توجد حجوزات هنا',
        subtitle: 'ستظهر الحجوزات حسب الحالة المختارة.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllAppointments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final a = list[index];

          final status = (a['status'] ?? 'pending').toString();
          final color = _getStatusColor(status);

          final patientId = (a['patientId'] ?? '').toString();
          final appointmentId = (a['id'] ?? '').toString();

          final dateText = (a['dateText'] ?? 'غير محدد').toString();
          final slot = (a['slot'] ?? 'غير محدد').toString();
          final photoUrl = (a['patientPhotoUrl'] ?? '').toString();

          final payStatus =
              (a['paymentStatus'] ?? 'unpaid').toString().toLowerCase();

          final payColor = _paymentColor(payStatus);
          final payText = _paymentText(payStatus);

          final methodRaw = (a['paymentMethod'] ?? '').toString();
          final methodText = _paymentMethodText(methodRaw);

          final paidAtMs = _safeInt(a['paidAt'], fallback: 0);
          final paidAtText = _formatPaidAt(paidAtMs);

          return _ProfessionalAppointmentCard(
            patientName: (a['patientName'] ?? 'مريض').toString(),
            patientPhone: (a['patientPhone'] ?? 'غير متوفر').toString(),
            patientImage: photoUrl,
            imageProvider: photoUrl.trim().isNotEmpty
                ? _patientImageProvider(photoUrl)
                : null,
            dateText: dateText,
            timeText: slot,
            price: _safeInt(a['price'], fallback: 0),
            status: status,
            statusText: _getStatusText(status),
            statusColor: color,
            paymentText: payText,
            paymentColor: payColor,
            methodText: methodText,
            paidAtText: paidAtText,
            onAccept: status == 'pending'
                ? () => _updateAppointmentStatus(
                      patientId: patientId,
                      appointmentId: appointmentId,
                      newStatus: 'confirmed',
                    )
                : null,
            onReject: status == 'pending'
                ? () => _updateAppointmentStatus(
                      patientId: patientId,
                      appointmentId: appointmentId,
                      newStatus: 'cancelled',
                    )
                : null,
            onCancel: status == 'confirmed'
                ? () => _updateAppointmentStatus(
                      patientId: patientId,
                      appointmentId: appointmentId,
                      newStatus: 'cancelled',
                    )
                : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _filterByStatus('confirmed');
    final pending = _filterByStatus('pending');
    final cancelled = _filterByStatus('cancelled');

    if (isLoading) {
      return const _DoctorAppointmentsShimmer();
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: kBg,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مواعيدي',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: kTealDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تابع طلبات الحجز وقم بقبولها أو رفضها بسهولة.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildCounterChip(
                    title: 'مؤكدة',
                    count: confirmed.length,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  _buildCounterChip(
                    title: 'انتظار',
                    count: pending.length,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  _buildCounterChip(
                    title: 'ملغية',
                    count: cancelled.length,
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: kTealDark,
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade700,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: 'مؤكدة (${confirmed.length})'),
              Tab(text: 'انتظار (${pending.length})'),
              Tab(text: 'ملغية (${cancelled.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentsList(confirmed),
              _buildAppointmentsList(pending),
              _buildAppointmentsList(cancelled),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfessionalAppointmentCard extends StatelessWidget {
  final String patientName;
  final String patientPhone;
  final String patientImage;
  final ImageProvider? imageProvider;
  final String dateText;
  final String timeText;
  final int price;
  final String status;
  final String statusText;
  final Color statusColor;
  final String paymentText;
  final Color paymentColor;
  final String methodText;
  final String paidAtText;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _ProfessionalAppointmentCard({
    required this.patientName,
    required this.patientPhone,
    required this.patientImage,
    required this.imageProvider,
    required this.dateText,
    required this.timeText,
    required this.price,
    required this.status,
    required this.statusText,
    required this.statusColor,
    required this.paymentText,
    required this.paymentColor,
    required this.methodText,
    required this.paidAtText,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withOpacity(0.10),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Icon(Icons.person_rounded, color: statusColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(patientPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AppointmentDetailBox(
                        icon: Icons.calendar_today_rounded,
                        title: 'التاريخ',
                        value: dateText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AppointmentDetailBox(
                        icon: Icons.access_time_rounded,
                        title: 'الوقت',
                        value: timeText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _AppointmentDetailBox(
                        icon: Icons.payments_rounded,
                        title: 'السعر',
                        value: '$price جنيه',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AppointmentDetailBox(
                        icon: Icons.credit_card_rounded,
                        title: 'الدفع',
                        value: methodText.isEmpty
                            ? paymentText
                            : '$paymentText • $methodText',
                        valueColor: paymentColor,
                      ),
                    ),
                  ],
                ),
                if (paidAtText.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _AppointmentDetailBox(
                    icon: Icons.verified_rounded,
                    title: 'تاريخ الدفع',
                    value: paidAtText,
                    valueColor: paymentColor,
                  ),
                ],
              ],
            ),
          ),
          if (onAccept != null || onReject != null || onCancel != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  if (onAccept != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('قبول'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  if (onAccept != null && onReject != null)
                    const SizedBox(width: 10),
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  if (onCancel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: const Text('إلغاء الموعد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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

class _AppointmentDetailBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _AppointmentDetailBox({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = valueColor ?? kTealDark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c, fontSize: 12.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppointmentState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyAppointmentState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.event_busy_rounded, size: 82, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// =========================
// Info Chip Widget (supports optional color)
// =========================
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            text,
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================
// ✅ Doctor Chat Tab
// ==============================
class DoctorChatTabPro extends StatelessWidget {
  const DoctorChatTabPro({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 90, color: kTealDark),
            const SizedBox(height: 20),
            const Text(
              'الدردشة مع المرضى',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'ميزة الدردشة قيد التطوير وستكون متاحة قريبًا',
              style: TextStyle(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================
// ✅ Doctor Stats Tab (كما هو عندك)
// ==============================
class DoctorStatsTabPro extends StatefulWidget {
  final String doctorId;

  const DoctorStatsTabPro({super.key, required this.doctorId});

  @override
  State<DoctorStatsTabPro> createState() => _DoctorStatsTabProState();
}

class _DoctorStatsTabProState extends State<DoctorStatsTabPro> {
  int totalAppointments = 0;
  double monthlyRevenue = 0.0;
  int newPatientsThisMonth = 0;

  Map<String, int> weeklyAppointments = {
    'السبت': 0,
    'الأحد': 0,
    'الإثنين': 0,
    'الثلاثاء': 0,
    'الأربعاء': 0,
    'الخميس': 0,
    'الجمعة': 0,
  };

  bool isLoading = true;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int _safeInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final doctorId = widget.doctorId.trim();
      if (doctorId.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final snapshot = await _dbRef
          .child('dashboardAppointments')
          .orderByChild('doctorId')
          .equalTo(doctorId)
          .get();

      int total = 0;
      double revenue = 0.0;
      final Set<String> thisMonthPatients = {};
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final weekMap = <String, int>{
        'السبت': 0,
        'الأحد': 0,
        'الإثنين': 0,
        'الثلاثاء': 0,
        'الأربعاء': 0,
        'الخميس': 0,
        'الجمعة': 0,
      };

      if (snapshot.exists && snapshot.value != null) {
        final apps = Map<dynamic, dynamic>.from(snapshot.value as Map);

        for (final value in apps.values) {
          if (value is! Map) continue;
          final appData = Map<dynamic, dynamic>.from(value);
          if (appData['visibleToDoctor'] != true) continue;
          if ((appData['status'] ?? '').toString() != 'confirmed') continue;

          total++;
          final date = (appData['date'] ?? '').toString().trim();
          final price = _safeInt(
            appData['appointmentPrice'] ?? appData['price'],
            fallback: 0,
          );
          final paymentMethod =
              (appData['paymentMethod'] ?? '').toString().toLowerCase();
          if (paymentMethod.contains('wallet') ||
              paymentMethod.contains('محفظ')) {
            revenue += price.toDouble();
          }

          if (date.length >= 7 && date.substring(0, 7) == currentMonth) {
            final patientId = (appData['patientId'] ?? '').toString().trim();
            if (patientId.isNotEmpty) thisMonthPatients.add(patientId);
          }

          final parsedDate = DateTime.tryParse(date);
          if (parsedDate != null) {
            final dayName = DateFormat('EEEE', 'ar').format(parsedDate);
            if (weekMap.containsKey(dayName)) {
              weekMap[dayName] = (weekMap[dayName] ?? 0) + 1;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        totalAppointments = total;
        monthlyRevenue = revenue;
        newPatientsThisMonth = thisMonthPatients.length;
        weeklyAppointments = weekMap;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _DoctorGenericPageShimmer();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إحصائياتك',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _StatBox(
                title: 'الحجوزات المؤكدة',
                value: totalAppointments.toString(),
                icon: Icons.check_circle_rounded,
              ),
              _StatBox(
                title: 'إيرادات الشهر',
                value: '${monthlyRevenue.toStringAsFixed(0)} جنيه',
                icon: Icons.payments_rounded,
              ),
              _StatBox(
                title: 'مرضى جدد',
                value: newPatientsThisMonth.toString(),
                icon: Icons.person_add_alt_1_rounded,
              ),
              const _StatBox(
                title: 'متوسط التقييم',
                value: '4.5',
                icon: Icons.star_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('أداء الأسبوع',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: weeklyAppointments.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kTeal.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: kTeal.withOpacity(0.25)),
                        ),
                        child: Text(
                          '${e.value} حجز',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: kTealDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

class DoctorProfileTabPro extends StatefulWidget {
  final String doctorId;
  final VoidCallback onLogout;

  const DoctorProfileTabPro({
    super.key,
    required this.doctorId,
    required this.onLogout,
  });

  @override
  State<DoctorProfileTabPro> createState() => _DoctorProfileTabProState();
}

class _DoctorProfileTabProState extends State<DoctorProfileTabPro> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();
  final ImagePicker _picker = ImagePicker();

  bool loading = true;
  bool saving = false;

  bool _hasChanges = false;
  bool _loadingIntoControllers = false;

  // Doctor info
  String name = '';
  String phone = '';
  String specialization = '';
  String photoUrl = '';
  double rating = 0.0;

  // ✅ IMPORTANT: ده رصيد المحفظة فقط (تعديل)
  double balance = 0.0;

  // Clinics
  List<Map<String, dynamic>> _clinics = [];

  int clinic0Price = 300;
  int clinic1Price = 300;

  String clinic0Phone = '';
  String clinic1Phone = '';

  String clinic0Address = '';
  String clinic1Address = '';

  // schedules as Map<String, dynamic>
  Map<String, dynamic> clinic0Schedule = {};
  Map<String, dynamic> clinic1Schedule = {};

  File? pickedImage;

  // Controllers
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final specCtrl = TextEditingController();

  final clinic0PriceCtrl = TextEditingController();
  final clinic1PriceCtrl = TextEditingController();

  final clinic0PhoneCtrl = TextEditingController();
  final clinic1PhoneCtrl = TextEditingController();

  final clinic0AddressCtrl = TextEditingController();
  final clinic1AddressCtrl = TextEditingController();

  // Days keys
  final Map<String, String> _daysAr = const {
    'sat': 'السبت',
    'sun': 'الأحد',
    'mon': 'الإثنين',
    'tue': 'الثلاثاء',
    'wed': 'الأربعاء',
    'thu': 'الخميس',
    'fri': 'الجمعة',
  };

  @override
  void initState() {
    super.initState();
    _attachDirtyListeners();
    _loadProfile();
  }

  void _attachDirtyListeners() {
    void onChange() {
      if (_loadingIntoControllers) return;
      _markDirty();
    }

    nameCtrl.addListener(onChange);
    phoneCtrl.addListener(onChange);
    specCtrl.addListener(onChange);

    clinic0PriceCtrl.addListener(onChange);
    clinic1PriceCtrl.addListener(onChange);

    clinic0PhoneCtrl.addListener(onChange);
    clinic1PhoneCtrl.addListener(onChange);

    clinic0AddressCtrl.addListener(onChange);
    clinic1AddressCtrl.addListener(onChange);
  }

  void _markDirty() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  // ✅ FIX: convert any Map<dynamic,dynamic> to Map<String,dynamic> (deep)
  Map<String, dynamic> _deepToStringDynamicMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      final result = <String, dynamic>{};
      raw.forEach((k, v) {
        result[k.toString()] = v is Map ? _deepToStringDynamicMap(v) : v;
      });
      return result;
    }
    return {};
  }

  int _parseInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    final s = (v ?? '').toString().trim();
    return int.tryParse(s) ?? fallback;
  }

  double _parseDouble(dynamic v, {double fallback = 0.0}) {
    if (v is num) return v.toDouble();
    final s = (v ?? '').toString().trim();
    return double.tryParse(s) ?? fallback;
  }

  String _norm(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return '';
    return s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), '');
  }

  bool _isWalletPayment(dynamic methodRaw) {
    final m = _norm(methodRaw);
    if (m.contains('محفظ')) return true;
    if (m == 'wallet') return true;
    if (m.contains('e-wallet') || m.contains('ewallet')) return true;
    return false;
  }

  bool _isFailedPaymentStatus(dynamic statusRaw) {
    final s = _norm(statusRaw);
    if (s.isEmpty) return false;
    return s == 'failed' ||
        s == 'fail' ||
        s == 'error' ||
        s == 'canceled' ||
        s == 'cancelled' ||
        s == 'declined' ||
        s == 'rejected' ||
        s == 'void';
  }

  ImageProvider _profileImage() {
    if (pickedImage != null) return FileImage(pickedImage!);

    if (photoUrl.startsWith('data:image')) {
      try {
        final b64 = photoUrl.split(',').last;
        final bytes = base64Decode(b64);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    if (photoUrl.isNotEmpty) return CachedNetworkImageProvider(photoUrl);
    return const AssetImage('assets/images/default_profile.png');
  }

  bool _isClinicValid(Map<String, dynamic> c) {
    final phone = (c['clinicPhone'] ?? '').toString().trim();
    final detailed =
        (c['detailedAddress'] ?? c['address'] ?? '').toString().trim();
    final gov = (c['governorate'] ?? '').toString().trim();
    final center = (c['center'] ?? '').toString().trim();

    final hasLocation =
        detailed.isNotEmpty || gov.isNotEmpty || center.isNotEmpty;
    final price = (c['price'] ?? '').toString().trim();
    final hasPrice = price.isNotEmpty;

    return phone.isNotEmpty || hasLocation || hasPrice;
  }

  List<Map<String, dynamic>> _extractClinics(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw == null) return result;

    if (raw is Map) {
      final entries = raw.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString()) ?? 0;
          final bi = int.tryParse(b.key.toString()) ?? 0;
          return ai.compareTo(bi);
        });

      for (final e in entries) {
        if (e.value is Map) {
          final clinic = _deepToStringDynamicMap(e.value);
          if (_isClinicValid(clinic)) result.add(clinic);
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final clinic = _deepToStringDynamicMap(item);
          if (_isClinicValid(clinic)) result.add(clinic);
        }
      }
    }
    return result;
  }

  String _joinClinicAddress(Map<String, dynamic> clinic) {
    final gov = (clinic['governorate'] ?? '').toString().trim();
    final center = (clinic['center'] ?? '').toString().trim();
    final detailed = (clinic['detailedAddress'] ?? '').toString().trim();
    final addressText = (clinic['address'] ?? '').toString().trim();

    final combined =
        [gov, center, detailed].where((e) => e.isNotEmpty).join(' - ').trim();
    return combined.isNotEmpty ? combined : addressText;
  }

  // ✅ schedule default shape
  Map<String, dynamic> _defaultSchedule() {
    final s = <String, dynamic>{};
    for (final day in _daysAr.keys) {
      s[day] = {
        'enabled': false,
        'from': '09:00',
        'to': '17:00',
      };
    }
    return s;
  }

  // ✅ merge missing days
  Map<String, dynamic> _normalizeSchedule(Map<String, dynamic> raw) {
    final base = _defaultSchedule();
    raw.forEach((dayKey, value) {
      if (value is Map) {
        final v = _deepToStringDynamicMap(value);
        base[dayKey] = {
          'enabled': (v['enabled'] == true),
          'from': (v['from'] ?? '09:00').toString(),
          'to': (v['to'] ?? '17:00').toString(),
        };
      }
    });
    return base;
  }

  Future<Map<String, dynamic>> _loadClinicSchedule(
      String doctorId, int clinicIndex) async {
    final snap = await _dbRef
        .child('users')
        .child(doctorId)
        .child('clinics')
        .child('$clinicIndex')
        .child('schedule')
        .get();

    if (!snap.exists || snap.value == null) return {};
    return _deepToStringDynamicMap(snap.value);
  }

  // ✅ FIX BALANCE: محفظة فقط (confirmed + wallet) واستبعد الفشل
  Future<double> _calculateWalletBalanceFromRoot(String doctorId) async {
    double calc = 0;
    final counted = <String>{};

    Future<void> readFromPath(String path) async {
      final snap = await _dbRef.child(path).get();
      if (!snap.exists || snap.value == null) return;

      final rootMap = _deepToStringDynamicMap(snap.value);

      void handleAppointment(
          String appointmentId, Map<String, dynamic> appData) {
        if (counted.contains(appointmentId)) return;

        final appDoctorId = (appData['doctorId'] ?? '').toString().trim();
        if (appDoctorId != doctorId) return;

        final status =
            (appData['status'] ?? appData['bookingStatus'] ?? '').toString();

        final price = _parseInt(
          appData['appointmentPrice'] ?? appData['price'],
          fallback: 0,
        );

        final method = (appData['paymentMethod'] ??
                appData['paymentType'] ??
                appData['method'] ??
                '')
            .toString();

        final payStatus =
            (appData['paymentStatus'] ?? appData['payStatus'] ?? '').toString();

        final isConfirmed = _norm(status) == 'confirmed';
        final isWallet = _isWalletPayment(method);
        final isFailed = _isFailedPaymentStatus(payStatus);

        if (isConfirmed && isWallet && !isFailed && price > 0) {
          calc += price.toDouble();
          counted.add(appointmentId);
        }
      }

      if (path == 'dashboardAppointments') {
        rootMap.forEach((appointmentId, value) {
          if (value is Map) {
            handleAppointment(
              appointmentId.toString(),
              _deepToStringDynamicMap(value),
            );
          }
        });
      } else {
        rootMap.forEach((patientId, patientApps) {
          if (patientApps is Map) {
            final apps = _deepToStringDynamicMap(patientApps);

            apps.forEach((appointmentId, value) {
              if (value is Map) {
                handleAppointment(
                  appointmentId.toString(),
                  _deepToStringDynamicMap(value),
                );
              }
            });
          }
        });
      }
    }

    await readFromPath('appointments');
    await readFromPath('dashboardAppointments');

    return calc;
  }

  // =========================
  // ✅ Load Profile
  // =========================
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => loading = true);

    try {
      final doctorId = widget.doctorId.trim();
      if (doctorId.isEmpty) {
        setState(() => loading = false);
        return;
      }

      final doctorSnap = await _dbRef.child('users').child(doctorId).get();
      if (!doctorSnap.exists || doctorSnap.value == null) {
        setState(() => loading = false);
        return;
      }

      final data = _deepToStringDynamicMap(doctorSnap.value);

      // Clinics
      final clinics = _extractClinics(data['clinics']);
      _clinics = clinics;

      final hasClinic0 = clinics.isNotEmpty;
      final hasClinic1 = clinics.length > 1;

      final c0 = hasClinic0 ? clinics[0] : <String, dynamic>{};
      final c1 = hasClinic1 ? clinics[1] : <String, dynamic>{};

      clinic0Price = hasClinic0 ? _parseInt(c0['price'], fallback: 300) : 300;
      clinic1Price = hasClinic1 ? _parseInt(c1['price'], fallback: 300) : 300;

      clinic0Phone = (c0['clinicPhone'] ?? '').toString().trim();
      clinic1Phone = (c1['clinicPhone'] ?? '').toString().trim();

      clinic0Address =
          (c0['detailedAddress'] ?? c0['address'] ?? '').toString().trim();
      clinic1Address =
          (c1['detailedAddress'] ?? c1['address'] ?? '').toString().trim();

      // Doctor basic
      name = (data['name'] ?? '').toString().trim();
      phone = (data['phone'] ?? '').toString().trim();
      specialization = (data['specialization'] ?? '').toString().trim();
      photoUrl = (data['photoUrl'] ?? '').toString().trim();
      rating = _parseDouble(data['rating'], fallback: 0.0);

      // ✅ Fast wallet read: use the balance already maintained on the doctor record.
      final walletRaw = data['wallet'];
      final nestedBalance = walletRaw is Map
          ? _deepToStringDynamicMap(walletRaw)['balance']
          : null;
      balance = _parseDouble(
        data['balance'] ?? data['walletBalance'] ?? nestedBalance,
        fallback: 0.0,
      );

      // ✅ Schedules are already included in the clinic payload.
      clinic0Schedule = _normalizeSchedule(
        hasClinic0 ? _deepToStringDynamicMap(c0['schedule']) : {},
      );
      clinic1Schedule = _normalizeSchedule(
        hasClinic1 ? _deepToStringDynamicMap(c1['schedule']) : {},
      );

      // Fill Controllers without marking dirty
      _loadingIntoControllers = true;

      nameCtrl.text = name;
      phoneCtrl.text = phone;
      specCtrl.text = specialization;

      clinic0PriceCtrl.text = clinic0Price.toString();
      clinic0PhoneCtrl.text = clinic0Phone;
      clinic0AddressCtrl.text = clinic0Address;

      clinic1PriceCtrl.text = hasClinic1 ? clinic1Price.toString() : '';
      clinic1PhoneCtrl.text = hasClinic1 ? clinic1Phone : '';
      clinic1AddressCtrl.text = hasClinic1 ? clinic1Address : '';

      _loadingIntoControllers = false;

      if (!mounted) return;
      setState(() {
        loading = false;
        _hasChanges = false;
        pickedImage = null;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // =========================
  // ✅ Pick Image
  // =========================
  Future<void> _pickImage() async {
    final x =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x == null) return;

    if (!mounted) return;
    setState(() {
      pickedImage = File(x.path);
      _hasChanges = true;
    });
  }

  Future<String?> _convertToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
    } catch (_) {
      return null;
    }
    return null;
  }

  // =========================
  // ✅ Time helpers
  // =========================
  TimeOfDay _parseTimeOfDay(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickScheduleTime({
    required int clinicIndex,
    required String dayKey,
    required bool isFrom,
  }) async {
    final schedule = clinicIndex == 0 ? clinic0Schedule : clinic1Schedule;
    final dayMap = _deepToStringDynamicMap(schedule[dayKey]);

    final current =
        _parseTimeOfDay((isFrom ? dayMap['from'] : dayMap['to']).toString());

    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: isFrom ? 'اختر وقت البداية' : 'اختر وقت النهاية',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      final updatedDay = _deepToStringDynamicMap(schedule[dayKey]);
      updatedDay[isFrom ? 'from' : 'to'] = _formatTime(picked);
      schedule[dayKey] = updatedDay;

      if (clinicIndex == 0) {
        clinic0Schedule = Map<String, dynamic>.from(schedule);
      } else {
        clinic1Schedule = Map<String, dynamic>.from(schedule);
      }

      _hasChanges = true;
    });
  }

  void _toggleDayEnabled({
    required int clinicIndex,
    required String dayKey,
    required bool enabled,
  }) {
    setState(() {
      final schedule = clinicIndex == 0 ? clinic0Schedule : clinic1Schedule;
      final updatedDay = _deepToStringDynamicMap(schedule[dayKey]);
      updatedDay['enabled'] = enabled;
      schedule[dayKey] = updatedDay;

      if (clinicIndex == 0) {
        clinic0Schedule = Map<String, dynamic>.from(schedule);
      } else {
        clinic1Schedule = Map<String, dynamic>.from(schedule);
      }

      _hasChanges = true;
    });
  }

  void _addAnotherClinic() {
    if (_clinics.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة العيادة الثانية بالفعل')),
      );
      return;
    }

    setState(() {
      _clinics.add(<String, dynamic>{
        'clinicPhone': '',
        'detailedAddress': '',
        'price': 300,
        'schedule': _defaultSchedule(),
      });

      clinic1Price = 300;
      clinic1Phone = '';
      clinic1Address = '';
      clinic1Schedule = _defaultSchedule();

      clinic1PriceCtrl.text = '300';
      clinic1PhoneCtrl.clear();
      clinic1AddressCtrl.clear();

      _hasChanges = true;
    });
  }

  // =========================
  // ✅ Save Profile
  // =========================
  Future<void> _saveProfile() async {
    if (saving) return;
    if (!_hasChanges) return;

    if (!mounted) return;
    setState(() => saving = true);

    try {
      final doctorId = widget.doctorId.trim();
      if (doctorId.isEmpty) return;

      final doctorUpdates = <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'specialization': specCtrl.text.trim(),
      };

      if (pickedImage != null) {
        final b64 = await _convertToBase64(pickedImage!);
        if (b64 != null) doctorUpdates['photoUrl'] = b64;
      }

      await _dbRef.child('users').child(doctorId).update(doctorUpdates);

      // Clinic 0 updates
      final c0Updates = <String, dynamic>{
        'price': int.tryParse(clinic0PriceCtrl.text.trim()) ?? 300,
        'clinicPhone': clinic0PhoneCtrl.text.trim(),
        'detailedAddress': clinic0AddressCtrl.text.trim(),
        'address': null,
        'schedule': clinic0Schedule,
      };

      await _dbRef
          .child('users')
          .child(doctorId)
          .child('clinics')
          .child('0')
          .update(c0Updates);

      // Clinic 1 only if exists
      if (_clinics.length > 1) {
        final c1Updates = <String, dynamic>{
          'price': int.tryParse(clinic1PriceCtrl.text.trim()) ?? 300,
          'clinicPhone': clinic1PhoneCtrl.text.trim(),
          'detailedAddress': clinic1AddressCtrl.text.trim(),
          'address': null,
          'schedule': clinic1Schedule,
        };

        await _dbRef
            .child('users')
            .child(doctorId)
            .child('clinics')
            .child('1')
            .update(c1Updates);
      }

      await _loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم حفظ التعديلات ✅'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الحفظ: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // =========================
  // ✅ Withdrawal Request (كما هو)
  // =========================
  Future<void> _requestWithdrawal() async {
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رصيد متاح للسحب')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();

    String method = 'wallet'; // wallet | instapay
    final accountCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    String normalizePhone(String s) {
      var t = s.trim();
      t = t.replaceAll(' ', '').replaceAll('-', '');
      if (t.startsWith('01') && t.length == 11) {
        return '+20${t.substring(1)}';
      }
      return t;
    }

    bool looksLikeEgyptPhone(String s) {
      final t = s.trim().replaceAll(' ', '');
      if (t.startsWith('01') && t.length == 11) return true;
      if (t.startsWith('+201') && t.length == 13) return true;
      return false;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'سحب الرصيد',
            style: TextStyle(fontWeight: FontWeight.w900, color: kTealDark),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogCtx).size.height * 0.65,
              maxWidth: 520,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setStateDialog) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرصيد الحالي: ${balance.toStringAsFixed(0)} جنيه',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'طريقة السحب',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'wallet',
                              label: Text('محفظة'),
                              icon: Icon(Icons.wallet_rounded),
                            ),
                            ButtonSegment(
                              value: 'instapay',
                              label: Text('InstaPay'),
                              icon: Icon(Icons.account_balance_rounded),
                            ),
                          ],
                          selected: {method},
                          onSelectionChanged: (set) {
                            setStateDialog(() => method = set.first);
                          },
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            shape: WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: accountCtrl,
                          decoration: InputDecoration(
                            labelText: method == 'wallet'
                                ? 'رقم المحفظة (مثال: 01xxxxxxxxx)'
                                : 'حساب InstaPay / رقم الحساب',
                            prefixIcon: Icon(
                              method == 'wallet'
                                  ? Icons.phone_rounded
                                  : Icons.account_balance_rounded,
                              color: kTealDark,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.isEmpty) {
                              return 'من فضلك اكتب ${method == 'wallet' ? 'رقم المحفظة' : 'حساب InstaPay'}';
                            }
                            if (method == 'wallet') {
                              final n = normalizePhone(s);
                              if (!looksLikeEgyptPhone(s) &&
                                  !looksLikeEgyptPhone(n)) {
                                return 'رقم المحفظة غير صحيح';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'المبلغ المطلوب (جنيه)',
                            prefixIcon: const Icon(Icons.payments_rounded,
                                color: kTealDark),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          validator: (v) {
                            final s = (v ?? '').trim();
                            final amount = double.tryParse(s) ?? 0;
                            if (s.isEmpty) return 'اكتب المبلغ';
                            if (amount <= 0) return 'اكتب مبلغ صحيح';
                            if (amount > balance) {
                              return 'المبلغ أكبر من الرصيد المتاح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kTeal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kTeal.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: kTealDark),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  method == 'wallet'
                                      ? 'سيتم تحويل المبلغ على رقم المحفظة بعد مراجعة الطلب.'
                                      : 'سيتم تحويل المبلغ على حساب InstaPay بعد مراجعة الطلب.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogCtx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('إرسال الطلب',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final doctorId = widget.doctorId.trim();
    final account = accountCtrl.text.trim();
    final amount = double.parse(amountCtrl.text.trim());

    try {
      final reqRef = _dbRef.child('withdrawal_requests').child(doctorId).push();

      await reqRef.set({
        'doctorId': doctorId,
        'doctorName': nameCtrl.text.trim(),
        'method': method, // wallet / instapay
        'accountNumber': method == 'wallet' ? normalizePhone(account) : account,
        'amount': amount,
        'status': 'pending',
        'requestedAt': ServerValue.timestamp,
        'doctorPhone': phoneCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إرسال طلب السحب ✅'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال طلب السحب: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _logout() async {
    await _storage.erase();
    widget.onLogout();
  }

  // =========================
  // ✅ UI Helpers (كما هو)
  // =========================
  Widget _infoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kTeal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: kTealDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kTealDark),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kTealDark, width: 1.5),
        ),
      ),
    );
  }

  Widget _withdrawalButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: balance > 0 ? _requestWithdrawal : null,
        icon: const Icon(Icons.account_balance_wallet_rounded),
        label: const Text('سحب الرصيد',
            style: TextStyle(fontWeight: FontWeight.w900)),
        style: OutlinedButton.styleFrom(
          foregroundColor: kTealDark,
          side: const BorderSide(color: kTealDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _scheduleEditor({
    required String title,
    required int clinicIndex,
    required Map<String, dynamic> schedule,
  }) {
    final activeDays = _daysAr.keys.where((day) {
      final dayMap = _deepToStringDynamicMap(schedule[day]);
      return dayMap['enabled'] == true;
    }).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kTeal.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: kTealDark.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: kTealDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: kTealDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$activeDays أيام عمل مفعلة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._daysAr.entries.map((e) {
            final dayKey = e.key;
            final dayName = e.value;

            final dayMap = _deepToStringDynamicMap(schedule[dayKey]);
            final enabled = dayMap['enabled'] == true;
            final from = (dayMap['from'] ?? '09:00').toString();
            final to = (dayMap['to'] ?? '17:00').toString();

            final cardBg = enabled
                ? Colors.green.withOpacity(0.10)
                : Colors.red.withOpacity(0.10);
            final cardBorder = enabled
                ? Colors.green.withOpacity(0.35)
                : Colors.red.withOpacity(0.35);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dayName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Switch(
                        value: enabled,
                        onChanged: (v) => _toggleDayEnabled(
                          clinicIndex: clinicIndex,
                          dayKey: dayKey,
                          enabled: v,
                        ),
                        activeColor: kTealDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width < 420
                            ? double.infinity
                            : null,
                        child: OutlinedButton.icon(
                          onPressed: enabled
                              ? () => _pickScheduleTime(
                                    clinicIndex: clinicIndex,
                                    dayKey: dayKey,
                                    isFrom: true,
                                  )
                              : null,
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(
                            'من: $from',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTealDark,
                            side: BorderSide(color: kTealDark.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width < 420
                            ? double.infinity
                            : null,
                        child: OutlinedButton.icon(
                          onPressed: enabled
                              ? () => _pickScheduleTime(
                                    clinicIndex: clinicIndex,
                                    dayKey: dayKey,
                                    isFrom: false,
                                  )
                              : null,
                          icon: const Icon(Icons.access_time_rounded),
                          label: Text(
                            'إلى: $to',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTealDark,
                            side: BorderSide(color: kTealDark.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    specCtrl.dispose();

    clinic0PriceCtrl.dispose();
    clinic1PriceCtrl.dispose();

    clinic0PhoneCtrl.dispose();
    clinic1PhoneCtrl.dispose();

    clinic0AddressCtrl.dispose();
    clinic1AddressCtrl.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const _DoctorProfileShimmer();

    final clinicsCount = _clinics.length;
    final hasClinic2 = clinicsCount > 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealDark, kTeal]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: kTeal.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 34, backgroundImage: _profileImage()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameCtrl.text.trim().isEmpty
                            ? 'دكتور'
                            : nameCtrl.text.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specCtrl.text.trim().isEmpty
                            ? 'التخصص غير محدد'
                            : specCtrl.text.trim(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _withdrawalButton(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  'الرصيد (محفظة)',
                  '${balance.toStringAsFixed(0)} جنيه',
                  Icons.account_balance_wallet_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _infoTile(
                  'عدد العيادات',
                  '$clinicsCount',
                  Icons.local_hospital_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  clinicsCount == 1 ? 'سعر الكشف' : 'سعر الكشف (عيادة 1)',
                  '${int.tryParse(clinic0PriceCtrl.text.trim()) ?? clinic0Price} جنيه',
                  Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: hasClinic2
                    ? _infoTile(
                        'سعر الكشف (عيادة 2)',
                        '${int.tryParse(clinic1PriceCtrl.text.trim()) ?? clinic1Price} جنيه',
                        Icons.payments_rounded,
                      )
                    : _infoTile(
                        'تقييم الحساب',
                        rating.toStringAsFixed(1),
                        Icons.star_rounded,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldCard(
            title: 'البيانات الأساسية',
            child: Column(
              children: [
                _textField(
                    controller: nameCtrl,
                    label: 'الاسم',
                    icon: Icons.person_rounded),
                const SizedBox(height: 10),
                _textField(
                  controller: phoneCtrl,
                  label: 'رقم الهاتف',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: specCtrl,
                  label: 'التخصص',
                  icon: Icons.medical_services_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _fieldCard(
            title: 'بيانات العيادة الأولى',
            child: Column(
              children: [
                _textField(
                  controller: clinic0PhoneCtrl,
                  label: 'رقم العيادة الأولى',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: clinic0AddressCtrl,
                  label: 'عنوان العيادة الأولى',
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: clinic0PriceCtrl,
                  label: 'سعر الكشف (عيادة 1)',
                  icon: Icons.monetization_on_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _scheduleEditor(
            title: 'مواعيد العيادة الأولى',
            clinicIndex: 0,
            schedule: clinic0Schedule,
          ),
          const SizedBox(height: 12),
          if (hasClinic2) ...[
            _fieldCard(
              title: 'بيانات العيادة الثانية',
              child: Column(
                children: [
                  _textField(
                    controller: clinic1PhoneCtrl,
                    label: 'رقم العيادة الثانية',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  _textField(
                    controller: clinic1AddressCtrl,
                    label: 'عنوان العيادة الثانية',
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 10),
                  _textField(
                    controller: clinic1PriceCtrl,
                    label: 'سعر الكشف (عيادة 2)',
                    icon: Icons.monetization_on_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _scheduleEditor(
              title: 'مواعيد العيادة الثانية',
              clinicIndex: 1,
              schedule: clinic1Schedule,
            ),
            const SizedBox(height: 12),
          ],
          if (!hasClinic2) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: saving ? null : _addAnotherClinic,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text(
                  'إضافة عيادة أخرى',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTealDark,
                  side: BorderSide(color: kTealDark.withOpacity(0.45)),
                  backgroundColor: kTeal.withOpacity(0.06),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera_back_rounded),
                  label: const Text('تغيير الصورة',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTealDark,
                    side: const BorderSide(color: kTealDark),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (saving || !_hasChanges) ? null : _saveProfile,
                  icon: saving
                      ? const Icon(Icons.hourglass_top_rounded)
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _hasChanges ? 'حفظ التعديلات' : 'لا يوجد تعديل',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTealDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('تسجيل الخروج',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ==============================
// Lightweight Shimmer (no package)
// ==============================
class _DoctorShimmer extends StatefulWidget {
  final Widget child;

  const _DoctorShimmer({required this.child});

  @override
  State<_DoctorShimmer> createState() => _DoctorShimmerState();
}

class _DoctorShimmerState extends State<_DoctorShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
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
      child: widget.child,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final value = _controller.value;
            return LinearGradient(
              begin: Alignment(-1.4 + (value * 2.8), 0),
              end: Alignment(-0.4 + (value * 2.8), 0),
              colors: const [
                Color(0xFFE7ECEF),
                Color(0xFFF8FAFC),
                Color(0xFFE7ECEF),
              ],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _DoctorDashboardShimmer extends StatelessWidget {
  const _DoctorDashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return _DoctorShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ShimmerBox(height: 210, radius: 26),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: _ShimmerBox(height: 105, radius: 20)),
                SizedBox(width: 10),
                Expanded(child: _ShimmerBox(height: 105, radius: 20)),
                SizedBox(width: 10),
                Expanded(child: _ShimmerBox(height: 105, radius: 20)),
              ],
            ),
            const SizedBox(height: 22),
            const _ShimmerBox(width: 150, height: 22),
            const SizedBox(height: 12),
            const _ShimmerBox(height: 130, radius: 20),
            const SizedBox(height: 12),
            const _ShimmerBox(height: 130, radius: 20),
          ],
        ),
      ),
    );
  }
}

class _DoctorAppointmentsShimmer extends StatelessWidget {
  const _DoctorAppointmentsShimmer();

  @override
  Widget build(BuildContext context) {
    return _DoctorShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: const [
          _ShimmerBox(height: 58, radius: 18),
          SizedBox(height: 18),
          _ShimmerBox(height: 165, radius: 22),
          SizedBox(height: 12),
          _ShimmerBox(height: 165, radius: 22),
          SizedBox(height: 12),
          _ShimmerBox(height: 165, radius: 22),
        ],
      ),
    );
  }
}

class _DoctorProfileShimmer extends StatelessWidget {
  const _DoctorProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return _DoctorShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: const [
          _ShimmerBox(height: 112, radius: 22),
          SizedBox(height: 14),
          _ShimmerBox(height: 54, radius: 16),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _ShimmerBox(height: 96, radius: 18)),
              SizedBox(width: 10),
              Expanded(child: _ShimmerBox(height: 96, radius: 18)),
            ],
          ),
          SizedBox(height: 14),
          _ShimmerBox(height: 250, radius: 22),
          SizedBox(height: 14),
          _ShimmerBox(height: 330, radius: 22),
        ],
      ),
    );
  }
}

class _DoctorGenericPageShimmer extends StatelessWidget {
  const _DoctorGenericPageShimmer();

  @override
  Widget build(BuildContext context) {
    return _DoctorShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
        children: const [
          _ShimmerBox(height: 90, radius: 20),
          SizedBox(height: 14),
          _ShimmerBox(height: 150, radius: 20),
          SizedBox(height: 14),
          _ShimmerBox(height: 150, radius: 20),
          SizedBox(height: 14),
          _ShimmerBox(height: 150, radius: 20),
        ],
      ),
    );
  }
}
