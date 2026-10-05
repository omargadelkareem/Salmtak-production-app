import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class BookAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final GetStorage _storage = GetStorage();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String? patientId;
  String? patientName;
  String? patientPhone;

  DateTime selectedDate = DateTime.now();
  String? selectedTimeSlot;

  bool isForSomeoneElse = false;
  String? otherPersonName;
  String? otherPersonPhone;

  bool payAtClinic = true;
  File? receiptImage;
  bool isLoading = false;

  Map<String, String> clinicSchedule = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadClinicSchedule();
  }

  Future<void> _loadUserData() async {
    patientId = _storage.read('userId');
    patientName = _storage.read('userName') ?? 'مريض';
    patientPhone = _storage.read('phone') ?? 'غير متوفر';
    setState(() {});
  }

  Future<void> _loadClinicSchedule() async {
    try {
      final snapshot = await _dbRef
          .child('users')
          .child(widget.doctor['id'])
          .child('clinicSchedule')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>?;
        if (data != null) {
          Map<String, String> schedule = {};
          data.forEach((key, value) {
            schedule[key as String] = value as String;
          });
          setState(() {
            clinicSchedule = schedule;
          });
        }
      }
    } catch (e) {
      print('خطأ جلب مواعيد العيادة: $e');
    }
  }

  List<String> _getAvailableTimeSlots() {
    final String dayName = DateFormat('EEEE', 'ar').format(selectedDate);
    final Map<String, String> arabicToEnglish = {
      'السبت': 'السبت',
      'الأحد': 'الأحد',
      'الإثنين': 'الإثنين',
      'الثلاثاء': 'الثلاثاء',
      'الأربعاء': 'الأربعاء',
      'الخميس': 'الخميس',
      'الجمعة': 'الجمعة',
    };

    final String dayKey = arabicToEnglish[dayName] ?? dayName;
    final String schedule = clinicSchedule[dayKey] ?? 'مغلق';

    if (schedule == 'مغلق') return [];

    final parts = schedule.split(' - ');
    if (parts.length != 2) return [];

    final DateFormat format = DateFormat('h:mm a', 'en_US');
    DateTime start = format.parse(parts[0]);
    DateTime end = format.parse(parts[1]);

    List<String> slots = [];
    DateTime current = start;

    while (current.isBefore(end)) {
      slots.add(DateFormat('h:mm a').format(current));
      current = current.add(const Duration(minutes: 30));
    }

    return slots;
  }

  Future<void> _pickReceiptImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        receiptImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _confirmBooking() async {
    if (selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار وقت الحجز أولاً')),
      );
      return;
    }

    if (isForSomeoneElse) {
      final bool nameEmpty =
          otherPersonName == null || otherPersonName!.trim().isEmpty;
      final bool phoneEmpty =
          otherPersonPhone == null || otherPersonPhone!.trim().isEmpty;

      if (nameEmpty || phoneEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('يرجى إدخال اسم ورقم الشخص الآخر بشكل صحيح')),
        );
        return;
      }
    }

    if (!payAtClinic && receiptImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رفع صورة إيصال التحويل')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final String doctorId = widget.doctor['id'];
      final String bookingFor =
          isForSomeoneElse ? otherPersonName!.trim() : patientName!;
      final String bookingPhone =
          isForSomeoneElse ? otherPersonPhone!.trim() : patientPhone!;

      final appointmentRef = _dbRef.child('appointments').push();
      final String appointmentId = appointmentRef.key!;

      String? receiptBase64;

      if (!payAtClinic && receiptImage != null) {
        try {
          final bytes = await receiptImage!.readAsBytes();
        } catch (e) {
          final bytes = await receiptImage!.readAsBytes();
          receiptBase64 = base64Encode(bytes);
        }
      }

      final Map<String, dynamic> appointmentData = {
        'patientId': patientId,
        'patientName': bookingFor,
        'patientPhone': bookingPhone,
        'doctorId': doctorId,
        'doctorName': widget.doctor['name'] ?? 'دكتور',
        'specialization': widget.doctor['specialization'] ?? 'غير محدد',
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'time': selectedTimeSlot,
        'status': 'pending',
        'price': widget.doctor['price'] ?? 300,
        'paymentMethod': payAtClinic ? 'عند الطبيب' : 'محفظة',
        'receiptImageBase64': receiptBase64,
        'createdAt': ServerValue.timestamp,
      };

      await appointmentRef.set(appointmentData);

      await Future.wait([
        _dbRef
            .child('users')
            .child(patientId!)
            .child('myAppointments')
            .child(appointmentId)
            .set(true),
        _dbRef
            .child('users')
            .child(doctorId)
            .child('appointments')
            .child(appointmentId)
            .set(true),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الحجز بنجاح! سيتم مراجعته قريبًا'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      print('خطأ في الحجز: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الحجز، حاول مرة أخرى')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSlots = _getAvailableTimeSlots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجز موعد',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الطبيب
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.doctor['photoUrl'] ??
                          'https://i.imgur.com/2h8Y9kP.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.doctor['name'] ?? 'دكتور',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.doctor['specialization'] ?? '',
                          style:
                              const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${widget.doctor['price'] ?? 300} جنيه',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // اختيار التاريخ
            const Text('اختر التاريخ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 350,
              child: CalendarDatePicker(
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                onDateChanged: (date) {
                  setState(() {
                    selectedDate = date;
                    selectedTimeSlot = null;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            // اختيار الوقت
            const Text('اختر الوقت المتاح',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            availableSlots.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد مواعيد متاحة في هذا اليوم',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: availableSlots.map((slot) {
                      final isSelected = selectedTimeSlot == slot;
                      return GestureDetector(
                        onTap: () => setState(() => selectedTimeSlot = slot),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 18),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3A8A)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1E3A8A)
                                    : Colors.grey.shade300,
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Text(
                            slot,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

            const SizedBox(height: 30),

            // حجز لمن
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الحجز لـ',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('نفسي'),
                          value: false,
                          groupValue: isForSomeoneElse,
                          onChanged: (v) =>
                              setState(() => isForSomeoneElse = v!),
                          activeColor: const Color(0xFF1E3A8A),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          title: const Text('شخص آخر'),
                          value: true,
                          groupValue: isForSomeoneElse,
                          onChanged: (v) =>
                              setState(() => isForSomeoneElse = v!),
                          activeColor: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  if (isForSomeoneElse) ...[
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => otherPersonName = v,
                      decoration: InputDecoration(
                        labelText: 'اسم الشخص',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => otherPersonPhone = v,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم التليفون',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // طريقة الدفع
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طريقة الدفع',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  RadioListTile<bool>(
                    title: const Text('دفع عند الطبيب'),
                    value: true,
                    groupValue: payAtClinic,
                    onChanged: (v) => setState(() => payAtClinic = v!),
                    activeColor: const Color(0xFF1E3A8A),
                  ),
                  RadioListTile<bool>(
                    title: const Text('دفع عن طريق المحفظة'),
                    value: false,
                    groupValue: payAtClinic,
                    onChanged: (v) => setState(() => payAtClinic = v!),
                    activeColor: const Color(0xFF1E3A8A),
                  ),
                  if (!payAtClinic) ...[
                    const SizedBox(height: 16),
                    const Text('يرجى التحويل على الرقم التالي:',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('01234567890',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickReceiptImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('رفع إيصال التحويل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    if (receiptImage != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(receiptImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.grey.shade400,
                blurRadius: 20,
                offset: const Offset(0, -10))
          ],
        ),
        child: SizedBox(
          height: 70,
          child: ElevatedButton(
            onPressed:
                isLoading || selectedTimeSlot == null ? null : _confirmBooking,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLoading || selectedTimeSlot == null
                  ? Colors.grey
                  : const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35)),
              elevation: 15,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    selectedTimeSlot == null
                        ? 'اختر وقت الحجز أولاً'
                        : 'تأكيد الحجز',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}
