import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:salmtak/features/screens/patient/all_specialties_screen.dart';
import 'package:salmtak/features/screens/patient/doctor_details_screen.dart';
import 'package:salmtak/features/screens/patient/specialty_doctors_screen.dart';
import 'package:url_launcher/url_launcher.dart';

const Color kPrimaryTeal = Color(0xFF14B8A6);
const Color kPrimaryTealDark = Color(0xFF0F766E);

/// =========================
/// Widget عام لعرض صورة الطبيب (يدعم Base64 أو URL)
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
    } catch (e) {
      // ignore: avoid_print
      print('خطأ في تحويل Base64: $e');
    }
  }

  return ClipRRect(
    borderRadius: borderRadius,
    child: CachedNetworkImage(
      imageUrl: photoUrl.isNotEmpty
          ? photoUrl
          : 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop',
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => _ShimmerBox(
        width: width,
        height: height,
        borderRadius: borderRadius!,
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child:
            Icon(Icons.person, size: width * 0.6, color: Colors.grey.shade600),
      ),
    ),
  );
}

/// =========================
/// Helpers: clinics extractor (List OR Map)
/// =========================
List<Map<String, dynamic>> extractClinics(dynamic rawClinics) {
  final out = <Map<String, dynamic>>[];
  if (rawClinics == null) return out;

  if (rawClinics is List) {
    for (final item in rawClinics) {
      if (item is Map) out.add(Map<String, dynamic>.from(item));
    }
    return out;
  }

  if (rawClinics is Map) {
    final m = Map<Object?, Object?>.from(rawClinics);
    for (final entry in m.entries) {
      final v = entry.value;
      if (v is Map) out.add(Map<String, dynamic>.from(v));
    }
    return out;
  }

  return out;
}

// شاشة المواعيد

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String userName = 'مستخدم';
  String userPhotoUrl = '';
  bool isLoadingUser = true;

  String? selectedGovernorateFilter;
  String? selectedCenterFilter;
  String? selectedSpecialtyFilter;
  bool _welcomeDialogShown = false;

  final List<String> governorates = ['سوهاج', 'أسيوط', 'المنيا'];

  final Map<String, List<String>> centersByGovernorate = {
    'سوهاج': [
      'سوهاج',
      'أخميم',
      'جرجا',
      'طما',
      'طهطا',
      'المنشأة',
      'دار السلام',
      'جهينة',
      'ساقلته',
      'المراغة',
      'البلينا',
    ],
    'أسيوط': [
      'أسيوط',
      'ديروط',
      'القوصية',
      'منفلوط',
      'أبنوب',
      'الفتح',
      'أبو تيج',
      'صدفا',
      'الغنايم',
      'ساحل سليم',
      'البداري',
    ],
    'المنيا': [
      'المنيا',
      'ملوي',
      'بني مزار',
      'مطاي',
      'سمالوط',
      'العدوة',
      'مغاغة',
      'أبو قرقاص',
      'دير مواس',
    ],
  };

  String userGovernorate = '';
  String userCenter = '';

  List<Map<String, dynamic>> allApprovedDoctors = [];
  List<Map<String, dynamic>> filteredDoctors = [];
  bool isLoadingDoctors = true;

  final GetStorage storage = GetStorage();
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  static const int _nearbyPreviewCount = 4;
  bool _showAllNearby = false;

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadApprovedDoctors();
  }

  bool get _isGuest {
    final String? userId = storage.read('userId');
    return userId == null || userId.isEmpty;
  }

  bool get _hasActiveFilters =>
      selectedGovernorateFilter != null ||
      selectedCenterFilter != null ||
      selectedSpecialtyFilter != null;

  List<String> get _availableSpecialties {
    final values = allApprovedDoctors
        .map((d) => (d['specialization'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty && value != 'غير محدد')
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<String> get _availableCenters {
    final governorate = selectedGovernorateFilter;
    if (governorate == null) return const [];
    return centersByGovernorate[governorate] ?? const [];
  }

  void _applyFilters() {
    if (!mounted) return;

    setState(() {
      filteredDoctors = allApprovedDoctors.where((doctor) {
        final specialty = (doctor['specialization'] ?? '').toString().trim();
        final governorate = (doctor['governorate'] ?? '').toString().trim();
        final center = (doctor['center'] ?? '').toString().trim();

        final governorateMatches = selectedGovernorateFilter == null ||
            governorate == selectedGovernorateFilter;

        final centerMatches =
            selectedCenterFilter == null || center == selectedCenterFilter;

        final specialtyMatches = selectedSpecialtyFilter == null ||
            specialty == selectedSpecialtyFilter;

        return governorateMatches && centerMatches && specialtyMatches;
      }).toList();
    });
  }

  void _selectGovernorate(String? value) {
    setState(() {
      selectedGovernorateFilter = value;
      selectedCenterFilter = null;
    });
    _applyFilters();
  }

  void _selectCenter(String? value) {
    setState(() => selectedCenterFilter = value);
    _applyFilters();
  }

  void _selectSpecialty(String? value) {
    setState(() => selectedSpecialtyFilter = value);
    _applyFilters();
  }

  void _clearFilters() {
    setState(() {
      selectedGovernorateFilter = null;
      selectedCenterFilter = null;
      selectedSpecialtyFilter = null;
      filteredDoctors = List<Map<String, dynamic>>.from(allApprovedDoctors);
    });
  }

  void _openDoctorDetails(Map<String, dynamic> doc) {
    final doctorId = (doc['id'] ?? '').toString();
    if (doctorId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorDetailsScreen(doctorId: doctorId),
      ),
    );
  }

  Future<void> loadUserData() async {
    setState(() => isLoadingUser = true);

    try {
      final String? userId = storage.read('userId');

      if (userId == null || userId.isEmpty) {
        setState(() {
          userName = 'مستخدم';
          userPhotoUrl = '';
          userGovernorate = '';
          userCenter = '';
          isLoadingUser = false;
        });
        return;
      }

      final snapshot = await dbRef.child('users').child(userId).get();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<Object?, Object?>.from(snapshot.value as Map);
        setState(() {
          userName = (data['name'] as String?)?.trim() ?? 'مستخدم';
          userPhotoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
          userGovernorate = (data['governorate'] ?? '').toString().trim();
          userCenter = (data['center'] ?? '').toString().trim();
          isLoadingUser = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowWelcomeDialog();
        });
      } else {
        setState(() => isLoadingUser = false);
      }
    } catch (e) {
      // ignore: avoid_print
      print('خطأ جلب بيانات المستخدم: $e');
      setState(() => isLoadingUser = false);
    }
  }

  // ✅ نفس extractClinics اللي عندك (لو موجودة عندك فوق في الملف سيبها)
  List<Map<String, dynamic>> extractClinics(dynamic rawClinics) {
    final out = <Map<String, dynamic>>[];
    if (rawClinics == null) return out;

    if (rawClinics is List) {
      for (final item in rawClinics) {
        if (item is Map) out.add(Map<String, dynamic>.from(item));
      }
      return out;
    }

    if (rawClinics is Map) {
      final m = Map<Object?, Object?>.from(rawClinics);
      for (final entry in m.entries) {
        final v = entry.value;
        if (v is Map) out.add(Map<String, dynamic>.from(v));
      }
      return out;
    }

    return out;
  }

  Future<void> _maybeShowWelcomeDialog() async {
    if (_welcomeDialogShown) return;

    // ✅ يظهر مرة واحدة فقط (يتخزن في GetStorage)
    final alreadyShown = storage.read('welcomeShown') == true;
    if (alreadyShown) return;

    _welcomeDialogShown = true;

    // تأخير بسيط عشان يبقى شكلها ناعم
    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "welcome",
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) {
        return _WelcomeCelebrationDialog(
          userName: _isGuest ? 'ضيفنا الجميل' : userName,
          governorate: userGovernorate,
          center: userCenter,
          onStart: () => Navigator.pop(context),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curve = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curve,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );

    // ✅ نخزن انه اتعرض مرة واحدة
    await storage.write('welcomeShown', true);
  }

  Future<void> loadApprovedDoctors() async {
    setState(() => isLoadingDoctors = true);

    try {
      final snapshot = await dbRef.child('users').get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          allApprovedDoctors = [];
          filteredDoctors = [];
          isLoadingDoctors = false;
        });
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final doctorsList = <Map<String, dynamic>>[];

      data.forEach((key, value) {
        if (value is Map) {
          final user = Map<Object?, Object?>.from(value);

          final isDoctor = user['role'] == 'doctor';
          final isApproved = user['isApproved'] == true;

          if (!isDoctor || !isApproved) return;

          final clinics = extractClinics(user['clinics']);
          final firstClinic = clinics.isNotEmpty ? clinics.first : null;

          final governorate =
              (firstClinic?['governorate'] ?? 'غير محدد').toString();
          final center = (firstClinic?['center'] ?? 'غير محدد').toString();
          final address =
              (firstClinic?['detailedAddress'] ?? '').toString().trim();

          final priceRaw = firstClinic?['price'];
          final int price = (priceRaw is num)
              ? priceRaw.toInt()
              : int.tryParse('$priceRaw') ?? 300;

          doctorsList.add({
            'id': key.toString(),
            'name': (user['name'] ?? 'دكتور').toString(),
            'phone': (user['phone'] ?? '').toString(),
            'specialization': (user['specialization'] ?? 'غير محدد').toString(),
            'photoUrl': (user['photoUrl'] ??
                    'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop')
                .toString(),
            'price': price,
            'governorate': governorate,
            'center': center,
            'detailedAddress': address,
            'joinedAt': user['approvedAt'] ??
                user['createdAt'] ??
                user['registeredAt'] ??
                user['updatedAt'] ??
                0,
          });
        }
      });

      setState(() {
        allApprovedDoctors = doctorsList;
        filteredDoctors = doctorsList;
        isLoadingDoctors = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('خطأ جلب الأطباء: $e');
      setState(() {
        allApprovedDoctors = [];
        filteredDoctors = [];
        isLoadingDoctors = false;
      });
    }
  }

  int _nearbyScore(Map<String, dynamic> d) {
    final docGov = (d['governorate'] ?? '').toString().trim();
    final docCenter = (d['center'] ?? '').toString().trim();

    int score = 100;

    if (userGovernorate.isNotEmpty && docGov.isNotEmpty) {
      if (docGov == userGovernorate) score = 10;
    }

    if (userCenter.isNotEmpty && docCenter.isNotEmpty) {
      if (docCenter == userCenter) score = 0;
    }

    return score;
  }

  List<Map<String, dynamic>> _sortedNearbyDoctors(
      List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) {
      final sa = _nearbyScore(a);
      final sb = _nearbyScore(b);
      if (sa != sb) return sa.compareTo(sb);

      final na = (a['name'] ?? '').toString();
      final nb = (b['name'] ?? '').toString();
      return na.compareTo(nb);
    });
    return copy;
  }

  // ✅ لو عندك buildDoctorImage فوق في الملف سيبه، لو مش موجود سيبها هنا
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
        final bytes = base64Decode(base64String);
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
      } catch (_) {
        // fallthrough to network placeholder below
      }
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: photoUrl.isNotEmpty
            ? photoUrl
            : 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop',
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _ShimmerBox(
          width: width,
          height: height,
          borderRadius: borderRadius!,
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: Icon(Icons.person,
              size: width * 0.6, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _newestDoctors(
    List<Map<String, dynamic>> doctors,
  ) {
    int timestampOf(Map<String, dynamic> doctor) {
      final raw = doctor['joinedAt'];

      if (raw is num) return raw.toInt();

      final parsedNumber = int.tryParse('$raw');
      if (parsedNumber != null) return parsedNumber;

      final parsedDate = DateTime.tryParse('$raw');
      return parsedDate?.millisecondsSinceEpoch ?? 0;
    }

    final copy = List<Map<String, dynamic>>.from(doctors);

    copy.sort((a, b) {
      final byDate = timestampOf(b).compareTo(timestampOf(a));
      if (byDate != 0) return byDate;

      final nameA = (a['name'] ?? '').toString();
      final nameB = (b['name'] ?? '').toString();
      return nameA.compareTo(nameB);
    });

    return copy.take(8).toList();
  }

  void openSpecialtyDoctors(String title, String value) {
    final filtered =
        allApprovedDoctors.where((d) => d['specialization'] == value).toList();

    // عندك SpecialtyDoctorsScreen في نفس الملف
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialtyDoctorsScreen(
          specialtyName: title,
          specialtyId: value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final nearbyAll = _sortedNearbyDoctors(allApprovedDoctors);
    final nearbyVisible = _showAllNearby
        ? nearbyAll
        : nearbyAll.take(_nearbyPreviewCount).toList();

    final newestDoctors = _newestDoctors(allApprovedDoctors);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([loadUserData(), loadApprovedDoctors()]);
            _applyFilters();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  isGuest: _isGuest,
                  isLoading: isLoadingUser,
                  userName: userName,
                  userPhotoUrl: userPhotoUrl,
                  userGovernorate: userGovernorate,
                  userCenter: userCenter,
                  onLoginTap: () {
                    // ضع هنا navigation للتسجيل لو عندك شاشة
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _DoctorFilterPanel(
                    governorates: governorates,
                    centers: _availableCenters,
                    specialties: _availableSpecialties,
                    selectedGovernorate: selectedGovernorateFilter,
                    selectedCenter: selectedCenterFilter,
                    selectedSpecialty: selectedSpecialtyFilter,
                    resultCount: filteredDoctors.length,
                    hasActiveFilters: _hasActiveFilters,
                    onGovernorateChanged: _selectGovernorate,
                    onCenterChanged: _selectCenter,
                    onSpecialtyChanged: _selectSpecialty,
                    onClear: _clearFilters,
                  ),
                ),
              ),
              if (_hasActiveFilters) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: _SectionHeader(
                      title: 'نتائج التصفية',
                      subtitle:
                          'تم العثور على ${filteredDoctors.length} طبيب مطابق لاختياراتك',
                    ),
                  ),
                ),
                if (isLoadingDoctors)
                  const SliverToBoxAdapter(
                    child: _DoctorListShimmer(count: 3),
                  )
                else if (filteredDoctors.isEmpty)
                  const SliverToBoxAdapter(
                    child: _FilterEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverList.separated(
                      itemCount: filteredDoctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doctor = filteredDoctors[index];
                        return _DoctorListCard(
                          doctor: doctor,
                          onOpen: () => _openDoctorDetails(doctor),
                          buildDoctorImage: buildDoctorImage,
                        );
                      },
                    ),
                  ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: _SectionHeader(
                      title: 'التخصصات',
                      subtitle: 'اختر التخصص المناسب ليظهر لك أفضل الأطباء',
                      actionText: 'عرض الكل',
                      onAction: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllSpecialtiesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 124,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        0,
                        16,
                        8,
                      ),
                      children: [
                        _SpecialtyTile(
                          title: 'أسنان',
                          icon: Icons.sentiment_satisfied_rounded,
                          color: const Color(0xFF2563EB),
                          onTap: () => openSpecialtyDoctors('أسنان', 'أسنان'),
                        ),
                        _SpecialtyTile(
                          title: 'جلدية',
                          icon: Icons.face_rounded,
                          color: const Color(0xFFDB2777),
                          onTap: () => openSpecialtyDoctors('جلدية', 'جلدية'),
                        ),
                        _SpecialtyTile(
                          title: 'عظام',
                          icon: Icons.healing_rounded,
                          color: const Color(0xFF16A34A),
                          onTap: () => openSpecialtyDoctors('عظام', 'عظام'),
                        ),
                        _SpecialtyTile(
                          title: 'نساء',
                          icon: Icons.pregnant_woman_rounded,
                          color: const Color(0xFF9333EA),
                          onTap: () =>
                              openSpecialtyDoctors('نساء', 'نساء وتوليد'),
                        ),
                        _SpecialtyTile(
                          title: 'عيون',
                          icon: Icons.visibility_rounded,
                          color: const Color(0xFF0F766E),
                          onTap: () => openSpecialtyDoctors('عيون', 'عيون'),
                        ),
                        _SpecialtyTile(
                          title: 'أنف وأذن',
                          icon: Icons.hearing_rounded,
                          color: const Color(0xFF4F46E5),
                          onTap: () => openSpecialtyDoctors(
                            'أنف وأذن',
                            'أنف وأذن وحنجرة',
                          ),
                        ),
                        _SpecialtyTile(
                          title: 'باطنة',
                          icon: Icons.medical_information_rounded,
                          color: const Color(0xFFDC2626),
                          onTap: () => openSpecialtyDoctors('باطنة', 'باطنة'),
                        ),
                        _SpecialtyTile(
                          title: 'علاج طبيعي',
                          icon: Icons.sports_gymnastics_rounded,
                          color: const Color(0xFF0891B2),
                          onTap: () => openSpecialtyDoctors(
                            'علاج طبيعي',
                            'علاج طبيعي',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: _SectionHeader(
                      title: 'جديد على سلامتك',
                      subtitle: 'أحدث الأطباء  ',
                    ),
                  ),
                ),
                if (isLoadingDoctors)
                  const SliverToBoxAdapter(
                    child: _NewDoctorsShimmer(count: 3),
                  )
                else if (newestDoctors.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 252,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        itemCount: newestDoctors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final doctor = newestDoctors[index];

                          return _NewDoctorCard(
                            doctor: doctor,
                            index: index,
                            onOpen: () => _openDoctorDetails(doctor),
                            buildDoctorImage: buildDoctorImage,
                          );
                        },
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: _SectionHeader(
                      title: 'أقرب الأطباء',
                      subtitle: 'مرتبين حسب منطقتك بشكل تلقائي',
                      actionText: nearbyAll.length > _nearbyPreviewCount
                          ? (_showAllNearby ? 'عرض أقل' : 'عرض المزيد')
                          : null,
                      onAction: nearbyAll.length > _nearbyPreviewCount
                          ? () => setState(
                                () => _showAllNearby = !_showAllNearby,
                              )
                          : null,
                    ),
                  ),
                ),
                if (isLoadingDoctors)
                  const SliverToBoxAdapter(
                    child: _NearbyDoctorsShimmerHorizontal(count: 3),
                  )
                else if (nearbyAll.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 26),
                      child: _NearbyEmptyState(),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 276,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        itemCount: nearbyVisible.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final doctor = nearbyVisible[index];
                          return _NearbyDoctorHorizontalCard(
                            doctor: doctor,
                            onOpen: () => _openDoctorDetails(doctor),
                            buildDoctorImage: buildDoctorImage,
                          );
                        },
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Container(height: 150, color: cs.surface),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCelebrationDialog extends StatelessWidget {
  final String userName;
  final String governorate;
  final String center;
  final VoidCallback onStart;

  const _WelcomeCelebrationDialog({
    required this.userName,
    required this.governorate,
    required this.center,
    required this.onStart,
  });

  static const Color _tealDark = Color(0xFF0F766E);
  static const Color _teal = Color(0xFF14B8A6);

  String get _locationText {
    final g = governorate.trim();
    final c = center.trim();

    if (g.isEmpty && c.isEmpty) return 'جاهز تبدأ رحلتك الطبية ✨';
    if (g.isNotEmpty && c.isEmpty) return 'من $g ✅';
    if (g.isEmpty && c.isNotEmpty) return 'من $c ✅';
    return '$g - $c ✅';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 18),
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 18),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // خلفية Gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        _tealDark,
                        _teal,
                        Color(0xFFECFEFF),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                ),

                // Confetti رسم خفيف
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ConfettiPainter(),
                    ),
                  ),
                ),

                // دوائر زينة
                Positioned(
                  top: -60,
                  right: -50,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // المحتوى
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // top row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text("🎉",
                                    style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  "أهلاً وسهلاً",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Icon circle
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              size: 36,
                              color: _tealDark,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "أهلاً يا $userName 👋",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "نورت التطبيق ✨\nدلوقتي تقدر تلاقي أفضل دكتور قريب منك وتحجز بسهولة",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          height: 1.35,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.88),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // location chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              _locationText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: onStart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _tealDark,
                            elevation: 18,
                            shadowColor: Colors.black.withOpacity(0.28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "يلا نبدأ 🚀",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "تقدر تقفل الرسالة دي في أي وقت ❤️",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final math.Random _r = math.Random(7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 70; i++) {
      final x = _r.nextDouble() * size.width;
      final y = _r.nextDouble() * size.height;
      final radius = 1.5 + (_r.nextDouble() * 3.5);

      final opacity = 0.08 + (_r.nextDouble() * 0.18);

      final colors = [
        const Color(0xFFFFFFFF),
        const Color(0xFF99F6E4),
        const Color(0xFF14B8A6),
        const Color(0xFF0F766E),
      ];

      paint.color = colors[_r.nextInt(colors.length)].withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =======================
// ✅ Fix هنا فقط: Avatar provider safely
// =======================

class _HomeHeader extends StatelessWidget {
  final bool isGuest;
  final bool isLoading;
  final String userName;
  final String userPhotoUrl;
  final String userGovernorate;
  final String userCenter;
  final VoidCallback onLoginTap;

  const _HomeHeader({
    required this.isGuest,
    required this.isLoading,
    required this.userName,
    required this.userPhotoUrl,
    required this.userGovernorate,
    required this.userCenter,
    required this.onLoginTap,
  });

  Future<void> openSupportWhatsApp(BuildContext context) async {
    const phone = '201080505068'; // ✅ لازم كود الدولة (20)
    const message = 'مرحبا، انا مستخدم التطبيق محتاج  دعم فني من فضلك';

    final whatsappAppUri = Uri.parse(
      'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}',
    );

    final webUri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    try {
      // ✅ جرّب يفتح واتساب مباشرة
      final openedApp = await launchUrl(
        whatsappAppUri,
        mode: LaunchMode.externalApplication,
      );

      // ✅ لو فشل يفتح web
      if (!openedApp) {
        final openedWeb = await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );

        if (!openedWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مش قادر أفتح واتساب على الجهاز ده')),
          );
        }
      }
    } catch (e) {
      // ✅ fallback قوي
      final openedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (!openedWeb && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء فتح واتساب: $e')),
        );
      }
    }
  }

  ImageProvider? _safeAvatarProvider(String url) {
    final v = url.trim();
    if (v.isEmpty) return null;

    if (v.startsWith('data:image')) {
      try {
        final bytes = base64Decode(v.split(',').last);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    // network
    return CachedNetworkImageProvider(v);
  }

  @override
  Widget build(BuildContext context) {
    final name = isLoading
        ? '...'
        : userName.trim().isEmpty
            ? 'مستخدم'
            : userName.trim();

    final location = _locationLine();
    final avatarProvider = _safeAvatarProvider(userPhotoUrl);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: const BoxDecoration(),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: avatarProvider == null
                        ? const Icon(Icons.person_rounded, color: Colors.white)
                        : Image(image: avatarProvider, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'هلا $name ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isGuest
                            ? 'تصفح كضيف، وسجّل عند الحجز'
                            : (location.isEmpty
                                ? 'ابحث عن طبيبك بسهولة'
                                : location),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                InkWell(
                  onTap: () async {
                    await openSupportWhatsApp(context);
                  },
                  child: const _HeaderChip(
                      icon: Icons.support_agent_rounded, text: ' تواصل معنا'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _locationLine() {
    final g = userGovernorate.trim();
    final c = userCenter.trim();
    if (g.isEmpty && c.isEmpty) return '';
    if (g.isEmpty) return c;
    if (c.isEmpty) return g;
    return '$g • $c';
  }
}

// =======================
// باقي Widgets (زي ما عندك)
// =======================

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorFilterPanel extends StatelessWidget {
  final List<String> governorates;
  final List<String> centers;
  final List<String> specialties;
  final String? selectedGovernorate;
  final String? selectedCenter;
  final String? selectedSpecialty;
  final int resultCount;
  final bool hasActiveFilters;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String?> onCenterChanged;
  final ValueChanged<String?> onSpecialtyChanged;
  final VoidCallback onClear;

  const _DoctorFilterPanel({
    required this.governorates,
    required this.centers,
    required this.specialties,
    required this.selectedGovernorate,
    required this.selectedCenter,
    required this.selectedSpecialty,
    required this.resultCount,
    required this.hasActiveFilters,
    required this.onGovernorateChanged,
    required this.onCenterChanged,
    required this.onSpecialtyChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE5ECEE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.045),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kPrimaryTeal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: kPrimaryTealDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حدد الطبيب المناسب لك',
                      style: TextStyle(
                        color: Color(0xFF172B31),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'المحافظة، المركز، والتخصص',
                      style: TextStyle(
                        color: Color(0xFF7A8B92),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveFilters)
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFFDC2626),
                        ),
                        SizedBox(width: 3),
                        Text(
                          'مسح',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FilterDropdown(
                  label: 'المحافظة',
                  hint: 'المحافظة',
                  icon: Icons.map_outlined,
                  value: selectedGovernorate,
                  items: governorates,
                  compact: true,
                  onChanged: onGovernorateChanged,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FilterDropdown(
                  label: 'المركز',
                  hint: 'المركز',
                  icon: Icons.location_city_outlined,
                  value: selectedCenter,
                  items: centers,
                  compact: true,
                  enabled: selectedGovernorate != null,
                  onChanged: onCenterChanged,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _FilterDropdown(
                  label: 'التخصص',
                  hint: 'التخصص',
                  icon: Icons.medical_services_outlined,
                  value: selectedSpecialty,
                  items: specialties,
                  compact: true,
                  onChanged: onSpecialtyChanged,
                ),
              ),
            ],
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: kPrimaryTealDark,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$resultCount طبيب مطابق لاختياراتك',
                      style: const TextStyle(
                        color: kPrimaryTealDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final bool enabled;
  final bool compact;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 5),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  enabled ? const Color(0xFF42545A) : const Color(0xFFA4AFB3),
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: safeValue,
          isExpanded: true,
          menuMaxHeight: 320,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: enabled ? const Color(0xFF64748B) : const Color(0xFFB8C1C5),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFB) : const Color(0xFFF1F4F5),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 3),
              child: Icon(
                icon,
                size: 15,
                color: enabled ? kPrimaryTealDark : const Color(0xFFAAB4B8),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 42,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF96A3A8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
            contentPadding: const EdgeInsetsDirectional.fromSTEB(5, 11, 5, 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5ECEE)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9EEF0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: kPrimaryTealDark,
                width: 1.25,
              ),
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF263A40),
            fontSize: 9.4,
            fontWeight: FontWeight.w800,
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF263A40),
                    fontSize: 9.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }).toList();
          },
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _FilterEmptyState extends StatelessWidget {
  const _FilterEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: kPrimaryTeal.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                size: 38,
                color: kPrimaryTealDark,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'لا يوجد أطباء مطابقون',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: kPrimaryTealDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جرّب تغيير المركز أو التخصص لعرض نتائج أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: kPrimaryTealDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withOpacity(0.60),
                    fontWeight: FontWeight.w200,
                  ),
                ),
              ]
            ],
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionText!,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SpecialtyTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 11),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 96,
            padding: const EdgeInsets.fromLTRB(8, 11, 8, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.09),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.14)),
                  ),
                  child: Icon(icon, color: color, size: 25),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF172B31),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const _ShimmerBox({
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..repeat();

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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.5 + (_controller.value * 3), 0),
              end: Alignment(-0.5 + (_controller.value * 3), 0),
              colors: const [
                Color(0xFFE8EDF2),
                Color(0xFFF8FAFC),
                Color(0xFFE8EDF2),
              ],
              stops: const [0.15, 0.5, 0.85],
            ),
          ),
        );
      },
    );
  }
}

class _DoctorListShimmer extends StatelessWidget {
  final int count;
  const _DoctorListShimmer({this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        children: List.generate(
          count,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF2)),
            ),
            child: const Row(
              children: [
                _ShimmerBox(width: 82, height: 82),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(width: 150, height: 14),
                      SizedBox(height: 10),
                      _ShimmerBox(width: 110, height: 11),
                      SizedBox(height: 10),
                      _ShimmerBox(width: 180, height: 11),
                      SizedBox(height: 12),
                      _ShimmerBox(width: 90, height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyDoctorsShimmerHorizontal extends StatelessWidget {
  final int count;

  const _NearbyDoctorsShimmerHorizontal({this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 276,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 20),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) {
          return Container(
            width: 226,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: double.infinity,
                  height: 116,
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                ),
                SizedBox(height: 13),
                _ShimmerBox(width: 150, height: 15),
                SizedBox(height: 9),
                _ShimmerBox(width: 105, height: 11),
                SizedBox(height: 9),
                _ShimmerBox(width: 170, height: 11),
                Spacer(),
                _ShimmerBox(
                  width: double.infinity,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(13)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NewDoctorsShimmer extends StatelessWidget {
  final int count;

  const _NewDoctorsShimmer({this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) {
          return Container(
            width: 184,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  width: double.infinity,
                  height: 112,
                  borderRadius: BorderRadius.all(Radius.circular(17)),
                ),
                SizedBox(height: 12),
                _ShimmerBox(width: 120, height: 14),
                SizedBox(height: 8),
                _ShimmerBox(width: 86, height: 10),
                SizedBox(height: 9),
                _ShimmerBox(width: 140, height: 10),
                Spacer(),
                _ShimmerBox(
                  width: double.infinity,
                  height: 34,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NewDoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final int index;
  final VoidCallback onOpen;
  final Widget Function(
    String photoUrl, {
    double width,
    double height,
    BorderRadius? borderRadius,
  })? buildDoctorImage;

  const _NewDoctorCard({
    required this.doctor,
    required this.index,
    required this.onOpen,
    this.buildDoctorImage,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final specialty = (doctor['specialization'] ?? 'غير محدد').toString();
    final governorate = (doctor['governorate'] ?? '').toString().trim();
    final center = (doctor['center'] ?? '').toString().trim();

    final location = [
      governorate,
      center,
    ].where((value) => value.isNotEmpty && value != 'غير محدد').join(' - ');

    final accentColors = <Color>[
      const Color(0xFF0F766E),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFF0891B2),
      const Color(0xFF16A34A),
      const Color(0xFFEA580C),
      const Color(0xFF4F46E5),
    ];

    final accent = accentColors[index % accentColors.length];

    return SizedBox(
      width: 184,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.045),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (buildDoctorImage != null)
                        buildDoctorImage!(
                          photoUrl,
                          width: double.infinity,
                          height: 112,
                          borderRadius: BorderRadius.circular(17),
                        ),
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'جديد',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF172B31),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.isEmpty ? 'الموقع غير محدد' : location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyDoctorHorizontalCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpen;
  final Widget Function(
    String photoUrl, {
    double width,
    double height,
    BorderRadius? borderRadius,
  })? buildDoctorImage;

  const _NearbyDoctorHorizontalCard({
    required this.doctor,
    required this.onOpen,
    this.buildDoctorImage,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final specialty = (doctor['specialization'] ?? 'غير محدد').toString();
    final governorate = (doctor['governorate'] ?? '').toString();
    final center = (doctor['center'] ?? '').toString();
    final address = (doctor['detailedAddress'] ?? '').toString().trim();

    final location = [
      governorate.trim(),
      center.trim(),
    ].where((value) => value.isNotEmpty && value != 'غير محدد').join(' - ');

    final rawPrice = doctor['price'];
    final price =
        rawPrice is num ? rawPrice.toInt() : int.tryParse('$rawPrice') ?? 300;

    return SizedBox(
      width: 226,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE7EEF0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.055),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 116,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (buildDoctorImage != null)
                        buildDoctorImage!(
                          photoUrl,
                          width: double.infinity,
                          height: 116,
                          borderRadius: BorderRadius.circular(17),
                        ),
                      PositionedDirectional(
                        top: 9,
                        start: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: Color(0xFFF59E0B),
                              ),
                              SizedBox(width: 3),
                              Text(
                                '4.8',
                                style: TextStyle(
                                  color: Color(0xFF172B31),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: 9,
                        end: 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryTealDark.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$price جنيه',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF12343B),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  specialty,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kPrimaryTealDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location.isEmpty
                            ? (address.isEmpty ? 'العنوان غير محدد' : address)
                            : location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryTealDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'عرض التفاصيل والحجز',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyEmptyState extends StatelessWidget {
  const _NearbyEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EEF0)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.location_searching_rounded,
            size: 38,
            color: kPrimaryTealDark,
          ),
          SizedBox(height: 10),
          Text(
            'لا يوجد أطباء قريبون حاليًا',
            style: TextStyle(
              color: Color(0xFF172B31),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'سيظهر هنا الأطباء الأقرب لمنطقتك عند توفرهم.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorListCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpen;
  final bool highlightNearby;

  /// Optional external builder (لو عندك هيلبر جاهز زي buildDoctorImage)
  final Widget Function(
    String photoUrl, {
    double width,
    double height,
    BorderRadius? borderRadius,
  })? buildDoctorImage;

  const _DoctorListCard({
    required this.doctor,
    required this.onOpen,
    this.highlightNearby = false,
    this.buildDoctorImage,
  });

  /// ✅ Internal safe image widget (Base64 OR URL)
  Widget _safeDoctorImage(
    String photoUrl, {
    double width = 82,
    double height = 82,
    BorderRadius? borderRadius,
  }) {
    borderRadius ??= BorderRadius.circular(18);

    // Base64 case: data:image/...;base64,XXXX
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                width: width,
                height: height,
                color: Colors.grey.shade200,
                child: Icon(Icons.person,
                    size: width * 0.55, color: Colors.grey.shade600),
              );
            },
          ),
        );
      } catch (_) {
        // fallback below
      }
    }

    const fallbackUrl =
        'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

    // URL case
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: photoUrl.isNotEmpty ? photoUrl : fallbackUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _ShimmerBox(
          width: width,
          height: height,
          borderRadius: borderRadius!,
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(Icons.person,
              size: width * 0.55, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final photoUrl = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final spec = (doctor['specialization'] ?? 'غير محدد').toString();

    final governorate = (doctor['governorate'] ?? 'غير محدد').toString();
    final center = (doctor['center'] ?? '').toString();
    final locationText =
        center.trim().isEmpty ? governorate : '$governorate - $center';

    final priceRaw = doctor['price'];
    final int price =
        (priceRaw is num) ? priceRaw.toInt() : int.tryParse('$priceRaw') ?? 300;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlightNearby
                  ? const Color(0xFF1E3A8A).withOpacity(0.25)
                  : cs.outlineVariant.withOpacity(0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  // ✅ SAFE IMAGE (Base64 / URL)
                  (buildDoctorImage != null)
                      ? buildDoctorImage!(
                          photoUrl,
                          width: 82,
                          height: 82,
                          borderRadius: BorderRadius.circular(18),
                        )
                      : _safeDoctorImage(
                          photoUrl,
                          width: 82,
                          height: 82,
                          borderRadius: BorderRadius.circular(18),
                        ),

                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (highlightNearby)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    const Color(0xFF1E3A8A).withOpacity(0.20),
                              ),
                            ),
                            child: const Text(
                              'قريب',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.22)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$price جنيه',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Color(0xFF1E3A8A),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorListCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpen;
  final bool highlightNearby;

  const DoctorListCard({
    super.key,
    required this.doctor,
    required this.onOpen,
    this.highlightNearby = false,
  });

  Widget _buildDoctorImage(
    String photoUrl, {
    double width = 82,
    double height = 82,
    BorderRadius? borderRadius,
  }) {
    borderRadius ??= BorderRadius.circular(18);

    const fallback =
        'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

    // ✅ Base64 image
    if (photoUrl.startsWith('data:image')) {
      try {
        final base64String = photoUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
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
      } catch (_) {
        // fall back to network
      }
    }

    // ✅ URL image
    final url = photoUrl.trim().isNotEmpty ? photoUrl.trim() : fallback;

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _ShimmerBox(
          width: width,
          height: height,
          borderRadius: borderRadius!,
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: Icon(Icons.person,
              size: width * 0.6, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final photoUrl = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final spec = (doctor['specialization'] ?? 'غير محدد').toString();

    final governorate = (doctor['governorate'] ?? 'غير محدد').toString();
    final center = (doctor['center'] ?? '').toString();
    final locationText =
        center.trim().isEmpty ? governorate : '$governorate - $center';

    final priceRaw = doctor['price'];
    final int price =
        (priceRaw is num) ? priceRaw.toInt() : int.tryParse('$priceRaw') ?? 300;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlightNearby
                  ? const Color(0xFF1E3A8A).withOpacity(0.25)
                  : cs.outlineVariant.withOpacity(0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  _buildDoctorImage(
                    photoUrl,
                    width: 82,
                    height: 82,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (highlightNearby)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    const Color(0xFF1E3A8A).withOpacity(0.20),
                              ),
                            ),
                            child: const Text(
                              'قريب',
                              style: TextStyle(
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.70),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.22)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$price جنيه',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Color(0xFF1E3A8A),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorPremiumCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onOpen;

  final String locationText;
  final int price;
  final double rating;

  const _DoctorPremiumCard({
    required this.doctor,
    required this.onOpen,
    required this.locationText,
    required this.price,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final photo = (doctor['photoUrl'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();
    final spec = (doctor['specialization'] ?? 'غير محدد').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Row(
            children: [
              // Photo
              Stack(
                children: [
                  buildDoctorImage(
                    photo,
                    width: 86,
                    height: 86,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_hospital_outlined,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: cs.onSurface.withOpacity(0.55)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            locationText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Price + Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded,
                                  color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '$price جنيه',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            ' التفاصيل',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDoctorsState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onReset;

  const _EmptyDoctorsState({
    required this.title,
    required this.subtitle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: Color(0xFF1E3A8A), size: 36),
            ),
            const SizedBox(height: 14),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.65),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة ضبط'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
