import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:salmtak/features/screens/patient/appointments_tab.dart';
import 'package:salmtak/features/screens/patient/favorites_tab.dart';
import 'package:salmtak/features/screens/patient/home_tab.dart';
import 'package:salmtak/features/screens/patient/join_as_doctor_screen.dart';
import 'package:salmtak/features/screens/patient/simple_bottom_nav_bar.dart';

import '../profile/profile_screen.dart';

class PatientView extends StatefulWidget {
  const PatientView({super.key});

  @override
  State<PatientView> createState() => _PatientViewState();
}

class _PatientViewState extends State<PatientView> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();

  int _selectedIndex = 2;
  String _userName = 'مستخدم';
  String _userPhotoUrl = '';

  late final List<Widget> _screens = const [
    AppointmentsTab(),
    JoinAsDoctorScreen(),
    HomeTab(),
    FavoritesTab(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedUser();
    _refreshCurrentUser();
  }

  void _loadCachedUser() {
    _userName = (_storage.read('cachedPatientName') ?? 'مستخدم').toString();
    _userPhotoUrl =
        (_storage.read('cachedPatientPhotoUrl') ?? '').toString().trim();
  }

  Future<void> _refreshCurrentUser() async {
    final userId = (_storage.read('userId') ?? '').toString().trim();
    if (userId.isEmpty) return;

    try {
      final snapshot = await _database.child('users/$userId').get();
      if (!snapshot.exists || snapshot.value is! Map) return;

      final data = Map<Object?, Object?>.from(snapshot.value as Map);
      final name = (data['name'] ?? 'مستخدم').toString().trim();
      final photoUrl = (data['photoUrl'] ?? '').toString().trim();

      await Future.wait([
        _storage.write('cachedPatientName', name),
        _storage.write('cachedPatientPhotoUrl', photoUrl),
      ]);

      if (!mounted) return;
      setState(() {
        _userName = name.isEmpty ? 'مستخدم' : name;
        _userPhotoUrl = photoUrl;
      });
    } catch (error, stackTrace) {
      debugPrint('PatientView user load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  ImageProvider? _avatarProvider() {
    final value = _userPhotoUrl.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(UriData.parse(value).contentAsBytes());
      } catch (_) {
        return null;
      }
    }
    return CachedNetworkImageProvider(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SimpleBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        userName: _userName,
        avatar: _avatarProvider(),
      ),
    );
  }
}
