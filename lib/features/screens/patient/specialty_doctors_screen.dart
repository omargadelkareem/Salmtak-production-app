import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:salmtak/features/screens/patient/doctor_details_screen.dart';

class SpecialtyDoctorsScreen extends StatefulWidget {
  const SpecialtyDoctorsScreen({
    super.key,
    required this.specialtyName,
    required this.specialtyId,
  });

  final String specialtyName;
  final String specialtyId;

  @override
  State<SpecialtyDoctorsScreen> createState() => _SpecialtyDoctorsScreenState();
}

class _SpecialtyDoctorsScreenState extends State<SpecialtyDoctorsScreen> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF6F7FB);

  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String _query = '';
  List<Map<String, dynamic>> _doctors = const [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeArabic(String value) {
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

  List<Map<String, dynamic>> get _visibleDoctors {
    final q = _normalizeArabic(_query);
    if (q.isEmpty) return _doctors;

    return _doctors.where((doctor) {
      final name = _normalizeArabic((doctor['name'] ?? '').toString());
      final specialty = _normalizeArabic(
        (doctor['specialization'] ?? widget.specialtyName).toString(),
      );
      final location = _normalizeArabic(_locationOf(doctor));
      return name.contains(q) || specialty.contains(q) || location.contains(q);
    }).toList();
  }

  Future<void> _loadDoctors() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final DataSnapshot snapshot = await _usersRef
          .orderByChild('specialization')
          .equalTo(widget.specialtyId)
          .get()
          .timeout(const Duration(seconds: 8));

      final List<Map<String, dynamic>> result = [];
      final dynamic raw = snapshot.value;

      if (raw is Map) {
        raw.forEach((dynamic key, dynamic value) {
          if (value is! Map) return;
          final doctor = Map<String, dynamic>.from(value);
          if (doctor['role']?.toString() != 'doctor' || doctor['isApproved'] != true) {
            return;
          }
          doctor['id'] = key.toString();
          result.add(doctor);
        });
      }

      result.sort((a, b) => _normalizeArabic((a['name'] ?? '').toString())
          .compareTo(_normalizeArabic((b['name'] ?? '').toString())));

      if (!mounted) return;
      setState(() {
        _doctors = result;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الأطباء. حاول مرة أخرى.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractClinics(dynamic rawClinics) {
    final clinics = <Map<String, dynamic>>[];
    if (rawClinics is List) {
      for (final item in rawClinics) {
        if (item is Map) clinics.add(Map<String, dynamic>.from(item));
      }
    } else if (rawClinics is Map) {
      for (final item in rawClinics.values) {
        if (item is Map) clinics.add(Map<String, dynamic>.from(item));
      }
    }
    return clinics;
  }

  String _locationOf(Map<String, dynamic> doctor) {
    final clinics = _extractClinics(doctor['clinics']);
    if (clinics.isEmpty) return 'الموقع غير محدد';
    final first = clinics.first;
    final governorate = (first['governorate'] ?? '').toString().trim();
    final center = (first['center'] ?? '').toString().trim();
    if (governorate.isEmpty && center.isEmpty) return 'الموقع غير محدد';
    if (governorate.isEmpty) return center;
    if (center.isEmpty) return governorate;
    return '$governorate - $center';
  }

  int _priceOf(Map<String, dynamic> doctor) {
    final clinics = _extractClinics(doctor['clinics']);
    final rawPrice = clinics.isNotEmpty ? clinics.first['price'] : doctor['price'];
    if (rawPrice is num) return rawPrice.toInt();
    return int.tryParse(rawPrice?.toString() ?? '') ?? 0;
  }

  void _openDoctor(Map<String, dynamic> doctor) {
    final doctorId = (doctor['id'] ?? '').toString();
    if (doctorId.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DoctorDetailsScreen(doctorId: doctorId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(widget.specialtyName,
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(onRefresh: _loadDoctors, child: _buildBody()),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث باسم الطبيب أو التخصص',
        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
        suffixIcon: _query.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          const Icon(Icons.cloud_off_rounded, size: 58, color: Colors.grey),
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Center(child: FilledButton(onPressed: _loadDoctors, child: const Text('إعادة المحاولة'))),
        ],
      );
    }

    final visible = _visibleDoctors;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: visible.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              _searchField(),
              if (_doctors.isEmpty || visible.isEmpty) ...[
                const SizedBox(height: 100),
                const Icon(Icons.search_off_rounded, size: 60, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  _doctors.isEmpty
                      ? 'لا يوجد أطباء متاحون في هذا التخصص حاليًا'
                      : 'لا توجد نتائج مطابقة لبحثك',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          );
        }

        final doctor = visible[index - 1];
        final price = _priceOf(doctor);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _openDoctor(doctor),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  buildDoctorImage(
                    (doctor['photoUrl'] ?? '').toString(),
                    width: 82,
                    height: 82,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((doctor['name'] ?? 'دكتور').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        const SizedBox(height: 6),
                        Text((doctor['specialization'] ?? widget.specialtyName).toString(),
                            style: const TextStyle(color: _primary, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Expanded(child: Text(_locationOf(doctor), maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade700))),
                        ]),
                        if (price > 0) ...[
                          const SizedBox(height: 8),
                          Text('الكشف: $price ج.م',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF15803D))),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
