import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:salmtak/features/screens/auth/auth_guard.dart';
import 'package:salmtak/features/screens/patient/home_tab.dart';
import 'package:salmtak/features/screens/patient/patient_view.dart';

const Color kTealDark = Color(0xFF0F766E);
const Color kTeal = Color(0xFF14B8A6);
const Color kBg = Color(0xFFF7FAFC);

class FinalReviewScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final bool isForSomeoneElse;
  final String? otherPersonName;
  final String? otherPersonPhone;
  final bool payAtClinic;
  final File? receiptImage;
  final int confirmationFee;
  final String walletNumber;
  final File? confirmationReceiptImage;

  const FinalReviewScreen({
    super.key,
    required this.doctor,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.isForSomeoneElse,
    this.otherPersonName,
    this.confirmationReceiptImage,
    this.otherPersonPhone,
    required this.payAtClinic,
    this.receiptImage,
    required this.confirmationFee,
    required this.walletNumber,
  });

  @override
  State<FinalReviewScreen> createState() => _FinalReviewScreenState();
}

class _FinalReviewScreenState extends State<FinalReviewScreen> {
  final GetStorage _storage = GetStorage();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  bool isLoading = false;

  String _patientName = 'مريض';
  String _patientPhone = 'غير متوفر';
  int _doctorPrice = 300;
  int _selectedClinicIndex = 0;
  String _selectedClinicAddress = '';
  String _selectedClinicPhone = '';
  String _selectedClinicName = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _resolvePatientData(),
      _resolveDoctorPrice(),
    ]);

    if (mounted) setState(() {});
  }

  Future<void> _resolvePatientData() async {
    try {
      final String? patientId = _storage.read('userId');

      if (patientId == null || patientId.isEmpty) {
        _patientName = 'مريض';
        _patientPhone = 'غير متوفر';
        return;
      }

      final storedName = _storage.read('userName');
      final storedPhone = _storage.read('userPhone') ?? _storage.read('phone');

      final nameOk =
          storedName != null && storedName.toString().trim().isNotEmpty;
      final phoneOk =
          storedPhone != null && storedPhone.toString().trim().isNotEmpty;

      if (nameOk) _patientName = storedName.toString().trim();
      if (phoneOk) _patientPhone = storedPhone.toString().trim();

      if (!nameOk || !phoneOk || _patientPhone == 'غير متوفر') {
        final snap = await _dbRef.child('users').child(patientId).get();

        if (snap.exists && snap.value != null) {
          final data = Map<Object?, Object?>.from(snap.value as Map);

          final name = (data['name'] ?? 'مريض').toString().trim();
          final phone = (data['phone'] ?? 'غير متوفر').toString().trim();

          _patientName = name.isNotEmpty ? name : 'مريض';
          _patientPhone = phone.isNotEmpty ? phone : 'غير متوفر';

          await _storage.write('userName', _patientName);
          await _storage.write('userPhone', _patientPhone);
          await _storage.write('phone', _patientPhone);
        }
      }
    } catch (e) {
      print('Resolve patient error: $e');
      _patientName = 'مريض';
      _patientPhone = 'غير متوفر';
    }
  }

  List<Map<String, dynamic>> _extractClinics(dynamic rawClinics) {
    final clinics = <Map<String, dynamic>>[];

    if (rawClinics is List) {
      for (final value in rawClinics) {
        if (value is Map) {
          clinics.add(Map<String, dynamic>.from(value));
        }
      }
    } else if (rawClinics is Map) {
      final entries = rawClinics.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));

      for (final entry in entries) {
        if (entry.value is Map) {
          final clinic = Map<String, dynamic>.from(entry.value);
          clinic.putIfAbsent('_firebaseKey', () => entry.key.toString());
          clinics.add(clinic);
        }
      }
    }

    return clinics;
  }

  int _resolveSelectedClinicIndexFromDoctor() {
    final candidates = <dynamic>[
      widget.doctor['selectedClinicIndex'],
      widget.doctor['clinicIndex'],
      widget.doctor['selectedClinic'],
      widget.doctor['selectedClinicId'],
      widget.doctor['clinicId'],
    ];

    for (final value in candidates) {
      if (value == null) continue;

      if (value is int && value >= 0) return value;

      final parsed = int.tryParse(value.toString().trim());
      if (parsed != null && parsed >= 0) return parsed;
    }

    return 0;
  }

  Map<String, dynamic>? _clinicPassedDirectly() {
    final candidates = <dynamic>[
      widget.doctor['selectedClinicData'],
      widget.doctor['selectedClinicDetails'],
      widget.doctor['clinic'],
    ];

    for (final value in candidates) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    return null;
  }

  void _applyClinicData(Map<String, dynamic> clinic, int index) {
    _selectedClinicIndex = index;

    final rawPrice =
        clinic['price'] ?? clinic['appointmentPrice'] ?? clinic['clinicPrice'];

    final parsedPrice = _parseInt(rawPrice, fallback: 0);
    if (parsedPrice > 0) {
      _doctorPrice = parsedPrice;
    }

    _selectedClinicAddress = (clinic['detailedAddress'] ??
            clinic['address'] ??
            clinic['clinicAddress'] ??
            '')
        .toString()
        .trim();

    _selectedClinicPhone =
        (clinic['clinicPhone'] ?? clinic['phone'] ?? '').toString().trim();

    _selectedClinicName =
        (clinic['name'] ?? clinic['clinicName'] ?? 'العيادة ${index + 1}')
            .toString()
            .trim();
  }

  Future<void> _resolveDoctorPrice() async {
    try {
      // 1) الأفضل: العيادة المختارة يتم تمريرها مباشرة من شاشة اختيار الموعد.
      final directClinic = _clinicPassedDirectly();
      final requestedIndex = _resolveSelectedClinicIndexFromDoctor();

      if (directClinic != null) {
        _applyClinicData(directClinic, requestedIndex);
        if (_doctorPrice > 0) return;
      }

      // 2) لو تم تمرير سعر العيادة المختارة صراحة.
      final dynamic selectedClinicPrice =
          widget.doctor['selectedClinicPrice'] ??
              widget.doctor['selectedAppointmentPrice'];

      final selectedParsed = _parseInt(selectedClinicPrice, fallback: 0);
      if (selectedParsed > 0) {
        _selectedClinicIndex = requestedIndex;
        _doctorPrice = selectedParsed;
        return;
      }

      final String doctorId = (widget.doctor['id'] ?? '').toString().trim();

      // 3) نحاول استخدام clinics الموجودة داخل doctor map.
      final localClinics = _extractClinics(widget.doctor['clinics']);

      if (localClinics.isNotEmpty) {
        final safeIndex = requestedIndex.clamp(0, localClinics.length - 1);
        _applyClinicData(localClinics[safeIndex], safeIndex);

        if (_doctorPrice > 0) return;
      }

      if (doctorId.isEmpty) {
        final dynamic fallbackRaw = widget.doctor['price'] ??
            widget.doctor['appointmentPrice'] ??
            widget.doctor['clinicPrice'];

        _doctorPrice = _parseInt(fallbackRaw, fallback: 300);
        return;
      }

      // 4) نقرأ كل العيادات ونختار نفس index الذي اختاره المستخدم.
      final clinicsSnapshot =
          await _dbRef.child('users').child(doctorId).child('clinics').get();

      if (clinicsSnapshot.exists && clinicsSnapshot.value != null) {
        final clinics = _extractClinics(clinicsSnapshot.value);

        if (clinics.isNotEmpty) {
          final safeIndex = requestedIndex.clamp(0, clinics.length - 1);
          _applyClinicData(clinics[safeIndex], safeIndex);

          if (_doctorPrice > 0) return;
        }
      }

      // آخر fallback فقط، وليس المصدر الأساسي.
      final dynamic fallbackRaw = widget.doctor['price'] ??
          widget.doctor['appointmentPrice'] ??
          widget.doctor['clinicPrice'];

      _doctorPrice = _parseInt(fallbackRaw, fallback: 300);
    } catch (e) {
      debugPrint('Resolve selected clinic price error: $e');

      final dynamic fallbackRaw = widget.doctor['selectedClinicPrice'] ??
          widget.doctor['price'] ??
          widget.doctor['appointmentPrice'] ??
          widget.doctor['clinicPrice'];

      _doctorPrice = _parseInt(fallbackRaw, fallback: 300);
    }
  }

  int _parseInt(dynamic v, {int fallback = 300}) {
    if (v == null) return fallback;
    if (v is num) return v.toInt();

    final s = v.toString().trim();
    return int.tryParse(s) ?? fallback;
  }

  Future<String?> _fileToBase64(File? file) async {
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<bool> _confirmBooking() async {
    setState(() => isLoading = true);

    try {
      final String? patientId = _storage.read('userId');

      if (patientId == null || patientId.isEmpty) {
        throw Exception('Guest can’t book');
      }

      await _resolvePatientData();
      await _resolveDoctorPrice();

      final String bookingFor = widget.isForSomeoneElse
          ? (widget.otherPersonName ?? '').trim()
          : _patientName;

      final String bookingPhone = widget.isForSomeoneElse
          ? (widget.otherPersonPhone ?? '').trim()
          : _patientPhone;

      String? receiptBase64;
      String? confirmationReceiptBase64;

      if (!widget.payAtClinic && widget.receiptImage != null) {
        receiptBase64 = await _fileToBase64(widget.receiptImage);
      }

      if (widget.confirmationReceiptImage != null) {
        confirmationReceiptBase64 =
            await _fileToBase64(widget.confirmationReceiptImage);
      }

      final appointmentRef =
          _dbRef.child('appointments').child(patientId).push();

      final String appointmentId = appointmentRef.key!;

      final String doctorId = (widget.doctor['id'] ?? '').toString();
      final String paymentMethod = widget.payAtClinic ? 'clinic' : 'wallet';
      final String paymentStatus = widget.payAtClinic ? 'unpaid' : 'pending';

      final Map<String, dynamic> appointmentData = {
        'id': appointmentId,
        'patientId': patientId,
        'patientName': bookingFor,
        'patientPhone': bookingPhone,
        'isForSomeoneElse': widget.isForSomeoneElse,
        'doctorId': doctorId,
        'doctorName': widget.doctor['name'] ?? '',
        'specialization': widget.doctor['specialization'] ?? '',
        'doctorPhotoUrl': widget.doctor['photoUrl'] ?? '',
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'dateText':
            DateFormat('EEEE, dd/MM/yyyy', 'ar').format(widget.selectedDate),
        'time': widget.selectedTimeSlot,
        'clinicIndex': _selectedClinicIndex,
        'selectedClinicIndex': _selectedClinicIndex,
        'clinicName': _selectedClinicName,
        'clinicAddress': _selectedClinicAddress,
        'clinicPhone': _selectedClinicPhone,
        'status': 'admin_pending',
        'bookingStatus': 'admin_pending',
        'visibleToDoctor': false,
        'adminApproved': false,
        'price': _doctorPrice,
        'appointmentPrice': _doctorPrice,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'walletNumber': widget.walletNumber,
        'confirmationFee': widget.confirmationFee,
        'receiptImageBase64': receiptBase64,
        'confirmationReceiptImageBase64': confirmationReceiptBase64,
        'hasReceiptImage': receiptBase64 != null,
        'hasConfirmationReceiptImage': confirmationReceiptBase64 != null,
        'createdAt': ServerValue.timestamp,
      };

      await appointmentRef.set(appointmentData);

      await Future.wait([
        _dbRef
            .child('users')
            .child(patientId)
            .child('myAppointments')
            .child(appointmentId)
            .set(true),
        // الحجز لا يضاف للطبيب هنا. يظهر للطبيب فقط بعد موافقة الأدمن من الداشبورد.

        // نسخة سهلة للداشبورد لعرض كل الحجوزات ومراجعتها أولاً
        _dbRef.child('dashboardAppointments').child(appointmentId).set({
          ...appointmentData,
          'mainPath': 'appointments/$patientId/$appointmentId',
        }),
      ]);

      return true;
    } catch (e) {
      print('Confirm booking error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحجز')),
        );
      }

      return false;
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: kBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kTeal.withOpacity(0.12),
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kTealDark,
                        boxShadow: [
                          BoxShadow(
                            color: kTeal.withOpacity(0.30),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'تم تأكيد حجزك بنجاح ✅',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kTealDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تم إرسال الحجز إلى العيادة، وسيتم التواصل معك قريبًا عبر مكالمة هاتفية لتأكيد الموعد.\n\nشكرًا لثقتك 💙',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                    color: kTealDark.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const PatientView(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealDark,
                      foregroundColor: Colors.white,
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'توجه للصفحة الرئيسية',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
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

  @override
  Widget build(BuildContext context) {
    final doctorName = (widget.doctor['name'] ?? 'دكتور').toString();
    final specialization =
        (widget.doctor['specialization'] ?? 'غير محدد').toString();
    final photoUrl = (widget.doctor['photoUrl'] ?? '').toString();

    final dateText =
        DateFormat('EEEE, dd/MM/yyyy', 'ar').format(widget.selectedDate);

    final bookingForText = widget.isForSomeoneElse
        ? (widget.otherPersonName ?? '').trim()
        : _patientName;

    final bookingPhoneText = widget.isForSomeoneElse
        ? (widget.otherPersonPhone ?? '').trim()
        : _patientPhone;

    final paymentText = widget.payAtClinic ? 'عند الطبيب' : 'محفظة';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              expandedHeight: 220,
              backgroundColor: kTealDark,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: const Text(
                'مراجعة الحجز النهائية',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            kTealDark,
                            kTeal,
                            kTeal.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.30),
                                  ),
                                ),
                                child: ClipOval(
                                  child: buildDoctorImage(
                                    photoUrl,
                                    width: 56,
                                    height: 56,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      doctorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      specialization,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.92),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.28),
                                  ),
                                ),
                                child: Text(
                                  '$_doctorPrice جنيه',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
            children: [
              _ProCard(
                title: 'ملخص الموعد',
                icon: Icons.event_available_rounded,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'التاريخ',
                      value: dateText,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'الوقت المحجوز',
                      value: widget.selectedTimeSlot,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.local_hospital_rounded,
                      label: 'العيادة المختارة',
                      value: _selectedClinicName.isEmpty
                          ? 'العيادة ${_selectedClinicIndex + 1}'
                          : _selectedClinicName,
                    ),
                    if (_selectedClinicAddress.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'عنوان العيادة',
                        value: _selectedClinicAddress,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'اسم المريض',
                      value: bookingForText.isEmpty ? 'مريض' : bookingForText,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.phone_rounded,
                      label: 'رقم الهاتف',
                      value: bookingPhoneText.isEmpty
                          ? 'غير متوفر'
                          : bookingPhoneText,
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.payments_rounded,
                      label: 'طريقة الدفع',
                      value: paymentText,
                      trailingChip: widget.payAtClinic
                          ? _Chip(
                              text: 'الدفع داخل العيادة',
                              bg: Colors.green.withOpacity(0.10),
                              fg: Colors.green,
                            )
                          : _Chip(
                              text: 'تم رفع إيصال التحويل',
                              bg: kTeal.withOpacity(0.10),
                              fg: kTealDark,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: kBg,
            border: Border(
              top: BorderSide(color: kTeal.withOpacity(0.25)),
            ),
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final ok = await AuthGuard.requireLogin(context);
                      if (!ok) return;

                      final success = await _confirmBooking();

                      if (!mounted) return;

                      if (success) {
                        await _showSuccessDialog();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لم يتم تأكيد الحجز، حاول مرة أخرى'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'تأكيد الحجز نهائيًا',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ProCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTeal.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kTealDark),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailingChip;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailingChip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kTeal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: kTealDark, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
        if (trailingChip != null) ...[
          const SizedBox(width: 10),
          trailingChip!,
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Chip({
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: fg,
          fontSize: 12,
        ),
      ),
    );
  }
}
