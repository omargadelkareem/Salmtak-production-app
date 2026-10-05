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

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _doctors = const [];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
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
          .get();

      final List<Map<String, dynamic>> result = [];
      final dynamic raw = snapshot.value;

      if (raw is Map) {
        raw.forEach((dynamic key, dynamic value) {
          if (value is! Map) return;

          final Map<String, dynamic> doctor = Map<String, dynamic>.from(value);

          final bool isDoctor = doctor['role']?.toString() == 'doctor';
          final bool isApproved = doctor['isApproved'] == true;
          if (!isDoctor || !isApproved) return;

          doctor['id'] = key.toString();
          result.add(doctor);
        });
      }

      result.sort((a, b) {
        final String aName = (a['name'] ?? '').toString();
        final String bName = (b['name'] ?? '').toString();
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        _doctors = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الأطباء. حاول مرة أخرى.';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractClinics(dynamic rawClinics) {
    final List<Map<String, dynamic>> clinics = [];

    if (rawClinics is List) {
      for (final dynamic item in rawClinics) {
        if (item is Map) clinics.add(Map<String, dynamic>.from(item));
      }
    } else if (rawClinics is Map) {
      for (final dynamic item in rawClinics.values) {
        if (item is Map) clinics.add(Map<String, dynamic>.from(item));
      }
    }

    return clinics;
  }

  String _locationOf(Map<String, dynamic> doctor) {
    final clinics = _extractClinics(doctor['clinics']);
    if (clinics.isEmpty) return 'الموقع غير محدد';

    final first = clinics.first;
    final String governorate = (first['governorate'] ?? '').toString().trim();
    final String center = (first['center'] ?? '').toString().trim();

    if (governorate.isEmpty && center.isEmpty) return 'الموقع غير محدد';
    if (governorate.isEmpty) return center;
    if (center.isEmpty) return governorate;
    return '$governorate - $center';
  }

  int _priceOf(Map<String, dynamic> doctor) {
    final clinics = _extractClinics(doctor['clinics']);
    final dynamic rawPrice =
        clinics.isNotEmpty ? clinics.first['price'] : doctor['price'];

    if (rawPrice is num) return rawPrice.toInt();
    return int.tryParse(rawPrice?.toString() ?? '') ?? 0;
  }

  void _openDoctor(Map<String, dynamic> doctor) {
    final String doctorId = (doctor['id'] ?? '').toString();
    if (doctorId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorDetailsScreen(doctorId: doctorId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          widget.specialtyName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDoctors,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 150),
          const Icon(Icons.cloud_off_rounded, size: 58, color: Colors.grey),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: _loadDoctors,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    if (_doctors.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 14),
          Text(
            'لا يوجد أطباء متاحون في هذا التخصص حاليًا',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _doctors.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doctor = _doctors[index];
        final int price = _priceOf(doctor);

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
                    doctor['photoUrl'].toString(),
                    width: 82,
                    height: 82,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (doctor['name'] ?? 'دكتور').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          (doctor['specialization'] ?? widget.specialtyName)
                              .toString(),
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _locationOf(doctor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        if (price > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'الكشف: $price ج.م',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
