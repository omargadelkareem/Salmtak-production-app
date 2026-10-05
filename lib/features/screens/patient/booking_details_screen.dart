import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'final_review_screen.dart';

// تعريف الألوان الثابتة (Teal Dark Theme)
const Color kTealDark = Color(0xFF0F766E);
const Color kTeal = Color(0xFF14B8A6);
const Color kTealLight = Color(0xFF5EEAD4);
const Color kBg = Color(0xFFF7FAFC);

class BookingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final DateTime selectedDate;
  final String selectedTimeSlot;

  /// بيانات العيادة التي اختارها المستخدم من شاشة مواعيد الطبيب.
  final int selectedClinicIndex;
  final Map<String, dynamic>? selectedClinic;

  const BookingDetailsScreen({
    super.key,
    required this.doctor,
    required this.selectedDate,
    required this.selectedTimeSlot,
    this.selectedClinicIndex = 0,
    this.selectedClinic,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final GetStorage _storage = GetStorage();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  static const int kConfirmationFee = 50;
  static const String kWalletNumber = '01080505068';

  String? patientId;
  String? patientName;
  String? patientPhone;

  bool isForSomeoneElse = false;
  String otherPersonName = '';
  String otherPersonPhone = '';

  bool payAtClinic = true;

  File? confirmationReceiptImage; // اختياري
  File? receiptImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// ✅ تحميل بيانات المريض الحقيقي (سواء متخزن أو نجيبه من Firebase)
  Future<void> _loadUserData() async {
    try {
      patientId = _storage.read('userId');

      // ✅ لو Guest
      if (patientId == null || patientId!.isEmpty) {
        patientName = 'مريض';
        patientPhone = 'غير متوفر';
        if (mounted) setState(() {});
        return;
      }

      // ✅ جرّب تجيب من التخزين الأول
      final storedName = _storage.read('userName');
      final storedPhone =
          _storage.read('userPhone') ?? _storage.read('phone'); // ✅ دعم مفتاحين

      final nameOk =
          storedName != null && storedName.toString().trim().isNotEmpty;
      final phoneOk =
          storedPhone != null && storedPhone.toString().trim().isNotEmpty;

      if (nameOk && phoneOk) {
        patientName = storedName.toString().trim();
        patientPhone = storedPhone.toString().trim();
        if (mounted) setState(() {});
        return;
      }

      // ✅ لو مش موجود في التخزين -> هاته من Firebase
      final snap = await _dbRef.child('users').child(patientId!).get();

      if (snap.exists && snap.value != null) {
        final data = Map<Object?, Object?>.from(snap.value as Map);

        patientName = (data['name'] ?? 'مريض').toString().trim();
        patientPhone = (data['phone'] ?? 'غير متوفر').toString().trim();

        // ✅ خزّنهم عشان المرة الجاية
        await _storage.write('userName', patientName);
        await _storage.write('userPhone', patientPhone);

        // (اختياري) لو عندك كود قديم بيستخدم phone
        await _storage.write('phone', patientPhone);
      } else {
        patientName = 'مريض';
        patientPhone = 'غير متوفر';
      }

      if (mounted) setState(() {});
    } catch (e) {
      // ignore: avoid_print
      print('Error loading patient data: $e');
      patientName = 'مريض';
      patientPhone = 'غير متوفر';
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickConfirmationReceiptImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      setState(() {
        confirmationReceiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && mounted) {
      setState(() {
        receiptImage = File(pickedFile.path);
      });
    }
  }

  bool _isValidPhone(String v) {
    final s = v.trim();
    if (s.isEmpty) return false;
    if (s.startsWith('01') && s.length == 11) return true;
    if (s.startsWith('+') && s.length >= 10) return true;
    return false;
  }

  bool get _canGoNext {
    // ✅ لو حجز لشخص آخر لازم الاسم والموبايل
    if (isForSomeoneElse) {
      if (otherPersonName.trim().isEmpty) return false;
      if (!_isValidPhone(otherPersonPhone)) return false;
    }

    // ✅ لو اختار المحفظة => الإيصال إجباري
    if (!payAtClinic && receiptImage == null) return false;

    return true;
  }

  Map<String, dynamic> _resolveSelectedClinic() {
    if (widget.selectedClinic != null) {
      return Map<String, dynamic>.from(widget.selectedClinic!);
    }

    final directCandidates = <dynamic>[
      widget.doctor['selectedClinicData'],
      widget.doctor['selectedClinicDetails'],
      widget.doctor['selectedClinic'],
      widget.doctor['clinic'],
    ];

    for (final value in directCandidates) {
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    final rawClinics = widget.doctor['clinics'];
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
          clinics.add(Map<String, dynamic>.from(entry.value));
        }
      }
    }

    if (clinics.isEmpty) return <String, dynamic>{};

    final doctorIndex = int.tryParse(
          (widget.doctor['selectedClinicIndex'] ??
                  widget.doctor['clinicIndex'] ??
                  widget.doctor['selectedClinicId'] ??
                  widget.selectedClinicIndex)
              .toString(),
        ) ??
        widget.selectedClinicIndex;

    final safeIndex = doctorIndex.clamp(0, clinics.length - 1);
    return clinics[safeIndex];
  }

  int _resolvedClinicIndex() {
    final raw = widget.doctor['selectedClinicIndex'] ??
        widget.doctor['clinicIndex'] ??
        widget.doctor['selectedClinicId'] ??
        widget.selectedClinicIndex;

    return int.tryParse(raw.toString()) ?? widget.selectedClinicIndex;
  }

  void _goNext() {
    if (!_canGoNext) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك أكمل بيانات الشخص الآخر إذا كنت تحجز له'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          final selectedClinic = _resolveSelectedClinic();
          final selectedClinicIndex = _resolvedClinicIndex();

          return FinalReviewScreen(
            doctor: {
              ...widget.doctor,
              'selectedClinicIndex': selectedClinicIndex,
              'clinicIndex': selectedClinicIndex,
              'selectedClinicData': selectedClinic,
              'selectedClinicPrice': selectedClinic['price'] ??
                  selectedClinic['appointmentPrice'] ??
                  selectedClinic['clinicPrice'],
            },
            selectedDate: widget.selectedDate,
            selectedTimeSlot: widget.selectedTimeSlot,
            isForSomeoneElse: isForSomeoneElse,
            otherPersonName: isForSomeoneElse ? otherPersonName.trim() : null,
            otherPersonPhone: isForSomeoneElse ? otherPersonPhone.trim() : null,
            payAtClinic: payAtClinic,
            confirmationFee: kConfirmationFee,
            walletNumber: kWalletNumber,
            confirmationReceiptImage: confirmationReceiptImage,
            receiptImage: receiptImage,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
        DateFormat('EEEE, dd/MM/yyyy', 'ar').format(widget.selectedDate);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('تفاصيل الحجز'),
        backgroundColor: kTealDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderSummaryCard(
              dateText: dateText,
              timeText: widget.selectedTimeSlot,
            ),
            const SizedBox(height: 16),
            _ProCard(
              title: 'تفاصيل الموعد',
              icon: Icons.event_available_rounded,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    title: 'التاريخ',
                    value: dateText,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    title: 'الوقت المحجوز',
                    value: widget.selectedTimeSlot,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProCard(
              title: 'الحجز لـ',
              icon: Icons.person_pin_circle_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SegmentedTwoOptions(
                    leftTitle: 'نفسي',
                    rightTitle: 'شخص آخر',
                    valueRight: isForSomeoneElse,
                    onChanged: (isRight) {
                      setState(() {
                        isForSomeoneElse = isRight;
                        if (!isForSomeoneElse) {
                          otherPersonName = '';
                          otherPersonPhone = '';
                        }
                      });
                    },
                  ),
                  if (isForSomeoneElse) ...[
                    const SizedBox(height: 14),
                    _ProTextField(
                      label: 'اسم الشخص',
                      hint: 'اكتب الاسم هنا',
                      icon: Icons.person_rounded,
                      onChanged: (v) => setState(() => otherPersonName = v),
                    ),
                    const SizedBox(height: 12),
                    _ProTextField(
                      label: 'رقم التليفون',
                      hint: 'مثال: 01xxxxxxxxx',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      onChanged: (v) => setState(() => otherPersonPhone = v),
                      errorText: otherPersonPhone.isEmpty
                          ? null
                          : (_isValidPhone(otherPersonPhone)
                              ? null
                              : 'رقم غير صحيح'),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    _HintChip(
                      text:
                          'بياناتك: ${patientName ?? 'مريض'} • ${patientPhone ?? 'غير متوفر'}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProCard(
              title: 'اختر طريقه دفع الكشف',
              icon: Icons.payments_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RadioTile(
                    title: 'دفع عند الطبيب',
                    subtitle: '    الدخول بأسبقيه الحضور  ',
                    value: true,
                    groupValue: payAtClinic,
                    onChanged: (v) {
                      setState(() {
                        payAtClinic = v;
                        if (payAtClinic) receiptImage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  _RadioTile(
                    title: 'دفع عن طريق المحفظة',
                    subtitle: 'حوّل قيمه الكشف ارفع إيصال التحويل',
                    value: false,
                    groupValue: payAtClinic,
                    onChanged: (v) => setState(() => payAtClinic = v),
                  ),
                  if (!payAtClinic) ...[
                    const SizedBox(height: 14),

                    // ✅ هنا فقط عرض الإيصال (مرة واحدة)
                    _WalletTransferCard(
                      walletNumber: kWalletNumber,
                      amountText: 'باقي الكشف',
                      onUpload: _pickReceiptImage,
                      uploadedImage: receiptImage,
                      onRemove: () => setState(() => receiptImage = null),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _canGoNext ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealDark,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                elevation: _canGoNext ? 8 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'التالي → مراجعة الحجز',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Components
// ────────────────────────────────────────────────

class _HeaderSummaryCard extends StatelessWidget {
  final String dateText;
  final String timeText;

  const _HeaderSummaryCard({
    required this.dateText,
    required this.timeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [kTealDark, kTeal, kTeal.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.fact_check_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'أنت على وشك تأكيد الحجز',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$dateText • $timeText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w700,
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
          )
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
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
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentedTwoOptions extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final bool valueRight;
  final ValueChanged<bool> onChanged;

  const _SegmentedTwoOptions({
    required this.leftTitle,
    required this.rightTitle,
    required this.valueRight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !valueRight
                      ? kTeal.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !valueRight ? kTeal : kTeal.withOpacity(0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    leftTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: !valueRight ? kTealDark : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color:
                      valueRight ? kTeal.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: valueRight ? kTeal : kTeal.withOpacity(0.25),
                  ),
                ),
                child: Center(
                  child: Text(
                    rightTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: valueRight ? kTealDark : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String text;

  const _HintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kTeal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: kTealDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: kTealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;
  final String? errorText;

  const _ProTextField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: kTealDark),
        errorText: errorText,
        filled: true,
        fillColor: kTeal.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: kTeal.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kTealDark, width: 1.5),
        ),
      ),
    );
  }
}

class _RadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool groupValue;
  final ValueChanged<bool> onChanged;

  const _RadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? kTeal.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kTeal.withOpacity(0.35) : kTeal.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? kTealDark : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? kTealDark : kTeal.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTransferCard extends StatelessWidget {
  final String walletNumber;
  final String amountText;
  final VoidCallback onUpload;
  final File? uploadedImage;
  final VoidCallback? onRemove;

  const _WalletTransferCard({
    required this.walletNumber,
    required this.amountText,
    required this.onUpload,
    this.uploadedImage,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kTeal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kTeal.withOpacity(0.25)),
            ),
            child: Text(
              walletNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: kTealDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text(
                'رفع إيصال التحويل ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // ✅ المعاينة هنا فقط
          if (uploadedImage != null) ...[
            const SizedBox(height: 12),
            _ReceiptPreview(
              file: uploadedImage!,
              onRemove: onRemove ?? () {},
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _ReceiptPreview({
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTeal.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.image_rounded, color: kTealDark),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('معاينة الإيصال',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, color: Colors.red),
                  tooltip: 'حذف',
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Image.file(
              file,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}
