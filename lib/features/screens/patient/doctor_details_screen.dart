import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:salmtak/features/screens/patient/select_date_time_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'booking_details_screen.dart';

// ────────────────────────────────────────────────
// تعريف الألوان الثابتة (نفس الألوان المستخدمة في لوحة الدكتور)
const Color kTealDark = Color(0xFF0F766E);
const Color kTeal = Color(0xFF14B8A6);
const Color kTealLight = Color(0xFF5EEAD4); // للـ accents الخفيفة
const Color kBg = Color(0xFFF7FAFC);
// ────────────────────────────────────────────────

/// =========================
/// Helpers: Doctor image (Base64 OR URL)
/// =========================
Widget buildDoctorImage(
  String photoUrl, {
  double width = 110,
  double height = 110,
  BorderRadius? borderRadius,
}) {
  borderRadius ??= BorderRadius.circular(24);

  if (photoUrl.startsWith('data:image')) {
    try {
      final String base64String = photoUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Icon(Icons.person,
                  size: width * 0.6, color: Colors.grey.shade600),
            );
          },
        ),
      );
    } catch (_) {}
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: CachedNetworkImage(
      imageUrl:
          photoUrl.isNotEmpty ? photoUrl : 'https://i.imgur.com/2h8Y9kP.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator(color: kTeal)),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child:
            Icon(Icons.person, size: width * 0.6, color: Colors.grey.shade600),
      ),
    ),
  );
}

ImageProvider getDoctorImageProvider(String photoUrl) {
  if (photoUrl.startsWith('data:image')) {
    try {
      final String base64String = photoUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } catch (_) {}
  }

  return CachedNetworkImageProvider(
    photoUrl.isNotEmpty ? photoUrl : 'https://i.imgur.com/2h8Y9kP.png',
  );
}

/// =========================
/// Doctor Details Screen
/// =========================
class DoctorDetailsScreen extends StatefulWidget {
  final String doctorId;

  const DoctorDetailsScreen({
    super.key,
    required this.doctorId,
  });

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen>
    with TickerProviderStateMixin {
  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');
  final GetStorage _storage = GetStorage();

  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _clinics = [];

  TabController? _tabController;
  bool _closing = false;

  List<Map<String, dynamic>> openDays = [];
  bool hasAvailableSlots = false;

  bool isLoadingDoctor = true;
  bool isLoadingSchedule = true;

  Map<int, List<Map<String, dynamic>>> _clinicOpenDays = {};

  bool isFavLoading = true;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadDoctor();
    _loadFavoriteState();
  }

  @override
  void dispose() {
    _closing = true;
    _tabController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _closing) return;
    setState(fn);
  }

  void _updateTabControllerLength(int newLength) {
    final len = newLength <= 0 ? 1 : newLength;

    if (_tabController != null && _tabController!.length == len) return;

    final oldController = _tabController;
    _tabController = TabController(length: len, vsync: this);

    _safeSetState(() {});

    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          oldController.dispose();
        } catch (_) {}
      });
    }
  }

  List<Map<String, dynamic>> _extractClinics(dynamic raw) {
    final result = <Map<String, dynamic>>[];

    if (raw == null) return result;

    if (raw is Map) {
      final entries = raw.entries.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a.key.toString());
          final bi = int.tryParse(b.key.toString());
          if (ai != null && bi != null) return ai.compareTo(bi);
          return a.key.toString().compareTo(b.key.toString());
        });

      for (final entry in entries) {
        final value = entry.value;
        if (value is Map) {
          final clinic = Map<String, dynamic>.from(value);
          clinic['_firebaseKey'] = entry.key.toString();
          result.add(clinic);
        }
      }
    } else if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      try {
        final temp = Map.from(raw as dynamic);
        for (var v in temp.values) {
          if (v is Map) result.add(Map<String, dynamic>.from(v));
        }
      } catch (_) {}
    }

    result.removeWhere((clinic) => clinic.isEmpty);
    return result;
  }

  int _parseInt(dynamic v, {int fallback = 300}) {
    if (v is num) return v.toInt();
    final s = (v ?? '').toString().trim();
    return int.tryParse(s) ?? fallback;
  }

  Future<void> _loadDoctor() async {
    _safeSetState(() {
      isLoadingDoctor = true;
      isLoadingSchedule = true;
      openDays = [];
      hasAvailableSlots = false;
      _doctor = null;
      _clinics = [];
      _clinicOpenDays = {};
    });

    try {
      final snap = await _usersRef.child(widget.doctorId).get();
      if (!mounted || _closing) return;

      if (!snap.exists || snap.value == null) {
        _safeSetState(() {
          isLoadingDoctor = false;
          isLoadingSchedule = false;
        });
        return;
      }

      final doctorMap = Map<String, dynamic>.from(snap.value as Map);
      doctorMap['id'] = widget.doctorId;

      final clinics = _extractClinics(doctorMap['clinics']);
      _updateTabControllerLength(clinics.isEmpty ? 1 : clinics.length);

      _safeSetState(() {
        _doctor = doctorMap;
        _clinics = clinics;
        isLoadingDoctor = false;
      });

      await _loadClinicSchedule();
    } catch (_) {
      if (!mounted || _closing) return;
      _safeSetState(() {
        isLoadingDoctor = false;
        isLoadingSchedule = false;
      });
    }
  }

  String _dayKeyToArabic(String key) {
    switch (key) {
      case 'sat':
        return 'السبت';
      case 'sun':
        return 'الأحد';
      case 'mon':
        return 'الإثنين';
      case 'tue':
        return 'الثلاثاء';
      case 'wed':
        return 'الأربعاء';
      case 'thu':
        return 'الخميس';
      case 'fri':
        return 'الجمعة';
    }
    return key;
  }

  Future<void> _loadClinicSchedule() async {
    _safeSetState(() {
      isLoadingSchedule = true;
      _clinicOpenDays = {};
      openDays = [];
      hasAvailableSlots = false;
    });

    try {
      final Map<int, List<Map<String, dynamic>>> all = {};

      for (int i = 0; i < _clinics.length; i++) {
        final snap = await _usersRef
            .child(widget.doctorId)
            .child('clinics')
            .child('$i')
            .child('schedule')
            .get();

        final openList = <Map<String, dynamic>>[];

        if (snap.exists && snap.value != null && snap.value is Map) {
          final data = Map<Object?, Object?>.from(snap.value as Map);

          data.forEach((dayKey, value) {
            if (value is Map) {
              final m = Map<Object?, Object?>.from(value);
              final from = (m['from'] ?? '').toString().trim();
              final to = (m['to'] ?? '').toString().trim();

              if (from.isNotEmpty && to.isNotEmpty) {
                openList.add({
                  'day': _dayKeyToArabic(dayKey.toString()),
                  'time': '$from - $to',
                });
              }
            }
          });
        }

        // ترتيب الأيام
        const order = {
          'السبت': 1,
          'الأحد': 2,
          'الإثنين': 3,
          'الثلاثاء': 4,
          'الأربعاء': 5,
          'الخميس': 6,
          'الجمعة': 7,
        };

        openList.sort((a, b) {
          final oa = order[a['day']] ?? 999;
          final ob = order[b['day']] ?? 999;
          return oa.compareTo(ob);
        });

        all[i] = openList;
      }

      _safeSetState(() {
        _clinicOpenDays = all;
        hasAvailableSlots = all.values.any((list) => list.isNotEmpty);
        openDays = all[0] ?? [];
      });
    } catch (_) {
      if (!mounted || _closing) return;
      _safeSetState(() {
        _clinicOpenDays = {};
        openDays = [];
        hasAvailableSlots = false;
      });
    } finally {
      _safeSetState(() => isLoadingSchedule = false);
    }
  }

  Future<void> _loadFavoriteState() async {
    _safeSetState(() => isFavLoading = true);

    try {
      final String? patientId = _storage.read('userId');
      if (patientId == null || patientId.isEmpty) {
        _safeSetState(() {
          isFavorite = false;
          isFavLoading = false;
        });
        return;
      }

      final favSnap = await _usersRef
          .child(patientId)
          .child('favorites')
          .child(widget.doctorId)
          .get();

      _safeSetState(() {
        isFavorite = favSnap.exists && favSnap.value != null;
        isFavLoading = false;
      });
    } catch (_) {
      _safeSetState(() {
        isFavorite = false;
        isFavLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final String? patientId = _storage.read('userId');
    if (patientId == null || patientId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجل الدخول أولاً لإضافة الطبيب للمفضلة')),
      );
      return;
    }

    _safeSetState(() => isFavLoading = true);

    try {
      final ref =
          _usersRef.child(patientId).child('favorites').child(widget.doctorId);

      if (isFavorite) {
        await ref.remove();
      } else {
        await ref.set(true);
      }

      _safeSetState(() {
        isFavorite = !isFavorite;
        isFavLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFavorite
              ? 'تمت الإضافة إلى المفضلة'
              : 'تمت الإزالة من المفضلة'),
        ),
      );
    } catch (_) {
      _safeSetState(() => isFavLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء تحديث المفضلة')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    var formatted = phoneNumber.trim();

    if (formatted.startsWith('01') && formatted.length == 11) {
      formatted = '+20${formatted.substring(1)}';
    }

    final uri = Uri(scheme: 'tel', path: formatted);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إجراء المكالمة')),
      );
    }
  }

  int? _arabicDayToDartWeekday(String day) {
    final d = day
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');

    switch (d) {
      case 'الاثنين':
      case 'اثنين':
      case 'الإثنين':
        return DateTime.monday;
      case 'الثلاثاء':
      case 'ثلاثاء':
        return DateTime.tuesday;
      case 'الاربعاء':
      case 'ألاربعاء':
      case 'اربعاء':
      case 'الأربعاء':
        return DateTime.wednesday;
      case 'الخميس':
        return DateTime.thursday;
      case 'الجمعة':
        return DateTime.friday;
      case 'السبت':
        return DateTime.saturday;
      case 'الاحد':
      case 'الأحد':
      case 'احد':
        return DateTime.sunday;
    }
    return null;
  }

  DateTime _nextDateForWeekday(int weekday, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = (weekday - today.weekday) % 7;
    return today.add(Duration(days: diff));
  }

  Future<void> _goToBookingForDay({
    required int clinicIndex,
    required Map<String, dynamic> clinic,
    required String day,
    required String time,
  }) async {
    if (_doctor == null) return;

    final wd = _arabicDayToDartWeekday(day);
    final chosenDate = wd == null ? DateTime.now() : _nextDateForWeekday(wd);

    final selectedClinic = Map<String, dynamic>.from(clinic);
    final selectedClinicPrice = _parseInt(
      selectedClinic['price'] ??
          selectedClinic['appointmentPrice'] ??
          selectedClinic['clinicPrice'],
      fallback: 300,
    );

    final doctorWithSelection = Map<String, dynamic>.from(_doctor!);

    doctorWithSelection['selectedDay'] = day;
    doctorWithSelection['selectedTime'] = time;
    doctorWithSelection['selectedDateIso'] =
        DateTime(chosenDate.year, chosenDate.month, chosenDate.day)
            .toIso8601String();

    doctorWithSelection['selectedClinicIndex'] = clinicIndex;
    doctorWithSelection['clinicIndex'] = clinicIndex;
    doctorWithSelection['selectedClinicId'] =
        selectedClinic['_firebaseKey'] ?? clinicIndex.toString();
    doctorWithSelection['selectedClinicData'] = selectedClinic;
    doctorWithSelection['selectedClinicPrice'] = selectedClinicPrice;

    final selectedSlot = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDateTimeScreen(
          doctor: doctorWithSelection,
          lockDate: true,
        ),
      ),
    );

    if (selectedSlot == null || selectedSlot.isEmpty || !mounted) return;

    doctorWithSelection['selectedSlot'] = selectedSlot;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(
          doctor: doctorWithSelection,
          selectedDate: chosenDate,
          selectedTimeSlot: selectedSlot,
          selectedClinicIndex: clinicIndex,
          selectedClinic: selectedClinic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingDoctor) {
      return const Scaffold(
        body: Center(
            child: Image(
          width: 50,
          height: 50,
          image: AssetImage('assets/images/logo.jpeg'),
        )),
      );
    }

    if (_doctor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطبيب')),
        body: const Center(child: Text('لم يتم العثور على بيانات هذا الطبيب')),
      );
    }

    final doctor = _doctor!;
    final clinics = _clinics;

    final String name = (doctor['name'] ?? 'دكتور').toString();
    final String specialization = (doctor['specialization'] ?? '').toString();

    final aboutStr = (doctor['about'] ?? '').toString().trim();
    final String about =
        aboutStr.isNotEmpty ? aboutStr : 'لا توجد نبذة عن الطبيب';

    final String photoUrl = (doctor['photoUrl'] ?? '').toString();

    final double rating =
        (doctor['rating'] is num) ? (doctor['rating'] as num).toDouble() : 4.8;
    final int reviewsCount = (doctor['reviewsCount'] is num)
        ? (doctor['reviewsCount'] as num).toInt()
        : 320;

    final tc = _tabController;
    if (tc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool hasClinics = clinics.isNotEmpty;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: kTealDark,
              elevation: 0,
              pinned: true,
              expandedHeight: 300,
              leading: _GlassIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                  child: Material(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isFavLoading ? null : _toggleFavorite,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: isFavLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: kTeal,
                                    strokeWidth: 2.5,
                                  ))
                              : Icon(
                                  isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
                    Positioned(
                      top: -80,
                      right: -60,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -90,
                      left: -60,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: _DoctorHeroHeader(
                          name: name,
                          specialization: specialization,
                          photoUrl: photoUrl,
                          rating: rating,
                          reviewsCount: reviewsCount,
                          onCallTap: () {
                            final phone = (doctor['phone'] ?? '').toString();
                            if (phone.trim().isNotEmpty) _makePhoneCall(phone);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: kBg,
                  child: TabBar(
                    controller: tc,
                    isScrollable: clinics.length > 1,
                    labelColor: kTealDark,
                    unselectedLabelColor: Colors.grey.shade600,
                    indicatorColor: kTeal,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    tabs: clinics.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      return Tab(text: 'العيادة $idx');
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
          body: hasClinics
              ? TabBarView(
                  controller: tc,
                  children: clinics.asMap().entries.map((entry) {
                    final index = entry.key;
                    final clinic = entry.value;

                    final String clinicPhone =
                        clinic['clinicPhone']?.toString().trim() ?? '';
                    final int price = _parseInt(clinic['price']);
                    final String governorate =
                        clinic['governorate']?.toString() ?? 'غير محدد';
                    final String center =
                        clinic['center']?.toString() ?? 'غير محدد';
                    final String address =
                        clinic['detailedAddress']?.toString() ?? 'غير محدد';

                    final clinicDays = _clinicOpenDays[index] ?? [];
                    final clinicHasSlots = clinicDays.isNotEmpty;

                    return _ClinicDetailsView(
                      price: price,
                      clinicPhone: clinicPhone,
                      governorate: governorate,
                      center: center,
                      address: address,
                      isLoadingSchedule: isLoadingSchedule,
                      openDays: clinicDays,
                      hasAvailableSlots: clinicHasSlots,
                      about: about,
                      onCallClinic: clinicPhone.isNotEmpty
                          ? () => _makePhoneCall(clinicPhone)
                          : null,
                      onBookTap: clinicHasSlots
                          ? (day, time) => _goToBookingForDay(
                                clinicIndex: index,
                                clinic: clinic,
                                day: day,
                                time: time,
                              )
                          : null,
                    );
                  }).toList(),
                )
              : _NoClinicView(
                  about: about,
                  isLoadingSchedule: isLoadingSchedule,
                  openDays: openDays,
                  hasAvailableSlots: hasAvailableSlots,
                  onBookTap: hasAvailableSlots
                      ? (day, time) => _goToBookingForDay(
                            clinicIndex: 0,
                            clinic: const <String, dynamic>{},
                            day: day,
                            time: time,
                          )
                      : null,
                ),
        ),
      ),
    );
  }
}

// باقي الكلاسات بدون تغيير في التصميم — فقط الألوان أصبحت Teal
// ──────────────────────────────────────────────────────────────

class _DoctorHeroHeader extends StatelessWidget {
  final String name;
  final String specialization;
  final String photoUrl;
  final double rating;
  final int reviewsCount;
  final VoidCallback? onCallTap;

  const _DoctorHeroHeader({
    required this.name,
    required this.specialization,
    required this.photoUrl,
    required this.rating,
    required this.reviewsCount,
    this.onCallTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.70),
                Colors.white.withOpacity(0.18),
              ],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.20),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: ClipOval(
              child: buildDoctorImage(
                photoUrl,
                width: 96,
                height: 96,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          specialization.isEmpty ? '—' : specialization,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.90),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GlassPill(
                icon: Icons.star_rounded, text: rating.toStringAsFixed(1)),
            const SizedBox(width: 10),
            _GlassPill(
                icon: Icons.reviews_rounded, text: '$reviewsCount تقييم'),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: onCallTap,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text(
              'اتصال',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kTealDark,
              elevation: 10,
              shadowColor: Colors.black.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GlassPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicDetailsView extends StatelessWidget {
  final int price;
  final String clinicPhone;
  final String governorate;
  final String center;
  final String address;

  final bool isLoadingSchedule;
  final List<Map<String, dynamic>> openDays;

  final String about;
  final VoidCallback? onCallClinic;

  final bool hasAvailableSlots;
  final void Function(String day, String time)? onBookTap;

  const _ClinicDetailsView({
    required this.price,
    required this.clinicPhone,
    required this.governorate,
    required this.center,
    required this.address,
    required this.isLoadingSchedule,
    required this.openDays,
    required this.about,
    required this.onCallClinic,
    required this.hasAvailableSlots,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionTitle(title: 'بيانات العيادة'),
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.payments_rounded,
          iconBg: kTeal.withOpacity(0.12),
          title: 'سعر الكشف',
          trailing: Text(
            '$price جنيه',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: kTealDark,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (clinicPhone.isNotEmpty)
          _InfoCard(
            onTap: onCallClinic,
            icon: Icons.phone_rounded,
            iconBg: kTeal.withOpacity(0.12),
            title: 'رقم العيادة',
            subtitle: clinicPhone,
            trailing: const Icon(Icons.call_rounded, color: kTealDark),
          ),
        if (clinicPhone.isNotEmpty) const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.location_on_rounded,
          iconBg: kTeal.withOpacity(0.12),
          title: 'العنوان',
          subtitle: '$governorate - $center\n$address',
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'الأيام المتاحة للحجز'),
        const SizedBox(height: 10),
        _ScheduleCarousel(
          isLoading: isLoadingSchedule,
          openDays: openDays,
          enabled: hasAvailableSlots,
          onBookTap: onBookTap,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'نبذة عن الطبيب'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kTeal.withOpacity(0.25)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Text(
              'عرض النبذة',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kTealDark,
              ),
            ),
            children: [
              Text(
                about,
                style: const TextStyle(
                  height: 1.6,
                  color: Colors.black87,
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

class _NoClinicView extends StatelessWidget {
  final String about;
  final bool isLoadingSchedule;
  final List<Map<String, dynamic>> openDays;

  final bool hasAvailableSlots;
  final void Function(String day, String time)? onBookTap;

  const _NoClinicView({
    required this.about,
    required this.isLoadingSchedule,
    required this.openDays,
    required this.hasAvailableSlots,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kTeal.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kTeal.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: kTealDark),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'لا توجد بيانات عيادة متاحة لهذا الطبيب حاليًا',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kTealDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'الأيام المتاحة للحجز'),
        const SizedBox(height: 10),
        _ScheduleCarousel(
          isLoading: isLoadingSchedule,
          openDays: openDays,
          enabled: hasAvailableSlots,
          onBookTap: onBookTap,
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'نبذة عن الطبيب'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kTeal.withOpacity(0.25)),
          ),
          child: Text(
            about,
            style: const TextStyle(
              height: 1.6,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleCarousel extends StatefulWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> openDays;

  final bool enabled;
  final void Function(String day, String time)? onBookTap;

  const _ScheduleCarousel({
    required this.isLoading,
    required this.openDays,
    required this.enabled,
    required this.onBookTap,
  });

  @override
  State<_ScheduleCarousel> createState() => _ScheduleCarouselState();
}

class _ScheduleCarouselState extends State<_ScheduleCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.90);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kTeal.withOpacity(0.25)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: kTeal),
          ),
        ),
      );
    }

    if (widget.openDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kTeal.withOpacity(0.25)),
        ),
        child: const Center(
          child: Text(
            'لا توجد مواعيد متاحة حاليًا',
            style: TextStyle(
              color: kTealDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.openDays.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final d = widget.openDays[i];
              final day = (d['day'] ?? '').toString();
              final time = (d['time'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _ScheduleDayCard(
                  day: day,
                  time: time,
                  enabled: widget.enabled,
                  onBookTap: widget.onBookTap,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.openDays.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? kTeal : kTeal.withOpacity(0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ScheduleDayCard extends StatelessWidget {
  final String day;
  final String time;

  final bool enabled;
  final void Function(String day, String time)? onBookTap;

  const _ScheduleDayCard({
    required this.day,
    required this.time,
    required this.enabled,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = _parseScheduleTime(time);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kTeal.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Icon(Icons.event_available_rounded, color: kTealDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  day,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: kTealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (parsed.hasRange)
            Row(
              children: [
                Expanded(child: _MiniChip(label: 'من', value: parsed.from!)),
                const SizedBox(width: 10),
                Expanded(child: _MiniChip(label: 'إلى', value: parsed.to!)),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kTeal.withOpacity(0.25)),
              ),
              child: Text(
                time,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: kTealDark,
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? () => onBookTap?.call(day, time) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled ? kTealDark : Colors.grey.shade300,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: enabled ? 8 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                enabled ? 'حجز موعد' : 'غير متاح',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: enabled ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedTimeRange {
  final String? from;
  final String? to;
  final String raw;

  const _ParsedTimeRange({required this.raw, this.from, this.to});

  bool get hasRange =>
      (from != null && from!.trim().isNotEmpty) &&
      (to != null && to!.trim().isNotEmpty);
}

_ParsedTimeRange _parseScheduleTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return _ParsedTimeRange(raw: raw);

  final reg = RegExp(r'(\d{1,2}(?::\d{2})?\s*(?:ص|م)?)');
  final matches = reg.allMatches(s).map((m) => m.group(1)!.trim()).toList();

  if (matches.length >= 2) {
    return _ParsedTimeRange(raw: raw, from: matches[0], to: matches[1]);
  }

  if (s.contains('-')) {
    final parts =
        s.split('-').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return _ParsedTimeRange(raw: raw, from: parts[0], to: parts[1]);
    }
  }

  return _ParsedTimeRange(raw: raw);
}

class _MiniChip extends StatelessWidget {
  final String label;
  final String value;

  const _MiniChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: kTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kTeal.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: kTealDark,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: kTealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kTeal.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg ?? kTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kTealDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kTealDark,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          height: 1.45,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 18,
          decoration: BoxDecoration(
            color: kTeal,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: kTealDark,
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
