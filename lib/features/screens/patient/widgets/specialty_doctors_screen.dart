import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:salmtak/features/screens/patient/doctor_details_screen.dart';

class SpecialtyDoctorsScreen extends StatefulWidget {
  final String specialtyName;
  final String specialtyId;
  final String? initialGovernorate;
  final String? initialCenter;

  const SpecialtyDoctorsScreen({
    super.key,
    required this.specialtyName,
    required this.specialtyId,
    this.initialGovernorate,
    this.initialCenter,
  });

  @override
  State<SpecialtyDoctorsScreen> createState() => _SpecialtyDoctorsScreenState();
}

class _SpecialtyDoctorsScreenState extends State<SpecialtyDoctorsScreen> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF5F7FA);

  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');

  final Map<String, List<String>> centersByGovernorate = const {
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

  bool isLoading = true;
  String? selectedGovernorate;
  String? selectedCenter;

  List<Map<String, dynamic>> allDoctors = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> filteredDoctors = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    selectedGovernorate = widget.initialGovernorate;
    selectedCenter = widget.initialCenter;
    _loadDoctors();
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matchesSpecialty(String doctorSpecialty) {
    final doctor = _normalize(doctorSpecialty);
    final id = _normalize(widget.specialtyId);
    final name = _normalize(widget.specialtyName);

    if (doctor.isEmpty) return false;

    // يعالج اختلاف المسافات والهمزات واختلاف الاسم المختصر عن الكامل.
    return doctor == id ||
        doctor == name ||
        doctor.contains(id) ||
        id.contains(doctor) ||
        doctor.contains(name) ||
        name.contains(doctor);
  }

  List<Map<String, dynamic>> _extractClinics(dynamic raw) {
    final result = <Map<String, dynamic>>[];

    if (raw is List) {
      for (final value in raw) {
        if (value is Map) result.add(Map<String, dynamic>.from(value));
      }
    } else if (raw is Map) {
      for (final value in raw.values) {
        if (value is Map) result.add(Map<String, dynamic>.from(value));
      }
    }

    return result;
  }

  Map<String, dynamic> _doctorFromFirebase(
    String id,
    Map<dynamic, dynamic> raw,
  ) {
    final clinics = _extractClinics(raw['clinics']);
    final firstClinic =
        clinics.isNotEmpty ? clinics.first : <String, dynamic>{};

    return {
      'id': id,
      'name': (raw['name'] ?? raw['doctorName'] ?? 'دكتور').toString(),
      'specialization': (raw['specialization'] ?? '').toString(),
      'photoUrl':
          (raw['photoUrl'] ?? raw['profileImage'] ?? raw['imageUrl'] ?? '')
              .toString(),
      'rating': raw['rating'] ?? 0,
      'governorate':
          (firstClinic['governorate'] ?? raw['governorate'] ?? '').toString(),
      'center': (firstClinic['center'] ?? raw['center'] ?? '').toString(),
      'address': (firstClinic['detailedAddress'] ??
              firstClinic['address'] ??
              raw['address'] ??
              '')
          .toString(),
      'price': firstClinic['price'] ??
          raw['appointmentPrice'] ??
          raw['price'] ??
          300,
    };
  }

  Future<void> _loadDoctors() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final snapshot = await _usersRef
          .orderByChild('role')
          .equalTo('doctor')
          .get()
          .timeout(const Duration(seconds: 10));

      final doctors = <Map<String, dynamic>>[];

      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        for (final entry in data.entries) {
          if (entry.value is! Map) continue;

          final raw = Map<dynamic, dynamic>.from(entry.value as Map);
          if (raw['isApproved'] != true) continue;

          final specialization = (raw['specialization'] ?? '').toString();

          if (!_matchesSpecialty(specialization)) continue;

          doctors.add(_doctorFromFirebase(entry.key.toString(), raw));
        }
      }

      if (!mounted) return;
      setState(() {
        allDoctors = doctors;
        isLoading = false;
      });

      _applyFilters();
    } catch (error) {
      debugPrint('SpecialtyDoctors load error: $error');
      if (!mounted) return;
      setState(() {
        allDoctors = <Map<String, dynamic>>[];
        filteredDoctors = <Map<String, dynamic>>[];
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final doctors = allDoctors.where((doctor) {
      final governorate = _normalize((doctor['governorate'] ?? '').toString());
      final center = _normalize((doctor['center'] ?? '').toString());

      final governorateOk = selectedGovernorate == null ||
          governorate == _normalize(selectedGovernorate!);

      final centerOk =
          selectedCenter == null || center == _normalize(selectedCenter!);

      return governorateOk && centerOk;
    }).toList();

    if (!mounted) return;
    setState(() => filteredDoctors = doctors);
  }

  void _clearFilters() {
    setState(() {
      selectedGovernorate = null;
      selectedCenter = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final centers = selectedGovernorate == null
        ? const <String>[]
        : centersByGovernorate[selectedGovernorate] ?? const <String>[];

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: Text(
          widget.specialtyName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CompactFilter(
                        title: selectedGovernorate ?? 'المحافظة',
                        icon: Icons.location_city_rounded,
                        onTap: () => _showSelectionSheet(
                          title: 'اختار المحافظة',
                          items: centersByGovernorate.keys.toList(),
                          onSelected: (value) {
                            setState(() {
                              selectedGovernorate = value;
                              selectedCenter = null;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactFilter(
                        title: selectedCenter ?? 'المركز',
                        icon: Icons.location_on_rounded,
                        enabled: selectedGovernorate != null,
                        onTap: () => _showSelectionSheet(
                          title: 'اختار المركز',
                          items: centers,
                          onSelected: (value) {
                            setState(() => selectedCenter = value);
                            _applyFilters();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedGovernorate != null || selectedCenter != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('مسح الفلاتر'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadDoctors,
                    child: filteredDoctors.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 90),
                              Icon(
                                Icons.medical_services_outlined,
                                size: 76,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'لا يوجد أطباء مطابقون',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'جرّب تغيير المحافظة أو المركز، أو اسحب الصفحة للتحديث.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                            itemCount: filteredDoctors.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final doctor = filteredDoctors[index];

                              return _VezeetaDoctorCard(
                                doctor: doctor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorDetailsScreen(
                                        doctorId:
                                            (doctor['id'] ?? '').toString(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.68,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (_, index) {
                    final value = items[index];
                    return ListTile(
                      title: Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(value);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactFilter extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _CompactFilter({
    required this.title,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 19, color: _SpecialtyDoctorsScreenState._primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VezeetaDoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final VoidCallback onTap;

  const _VezeetaDoctorCard({
    required this.doctor,
    required this.onTap,
  });

  ImageProvider? _imageProvider(String value) {
    final url = value.trim();
    if (url.isEmpty) return null;

    if (url.startsWith('data:image')) {
      try {
        final Uint8List bytes = base64Decode(url.split(',').last);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }

    return CachedNetworkImageProvider(url);
  }

  int _price(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 300;
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageProvider((doctor['photoUrl'] ?? '').toString());
    final rating = double.tryParse((doctor['rating'] ?? '0').toString()) ?? 0.0;
    final governorate = (doctor['governorate'] ?? '').toString();
    final center = (doctor['center'] ?? '').toString();
    final location = [
      governorate,
      center,
    ].where((value) => value.trim().isNotEmpty).join(' - ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: const Color(0xFFE6FFFB),
                backgroundImage: image,
                child: image == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: _SpecialtyDoctorsScreenState._primary,
                      )
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'د. ${(doctor['name'] ?? 'دكتور').toString()}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F4C81),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      (doctor['specialization'] ?? '').toString(),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating == 0
                              ? 'طبيب معتمد'
                              : rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location.isEmpty ? 'العنوان غير محدد' : location,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Text(
                          'الكشف ${_price(doctor['price'])} جنيه',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'احجز الآن',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
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
