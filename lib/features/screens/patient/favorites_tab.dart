import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:salmtak/features/screens/patient/doctor_details_screen.dart';

class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final GetStorage _storage = GetStorage();

  bool isLoading = true;

  List<Map<String, dynamic>> favDoctors = [];
  List<Map<String, dynamic>> filteredDoctors = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => filteredDoctors = favDoctors);
      return;
    }

    setState(() {
      filteredDoctors = favDoctors.where((d) {
        final name = (d['name'] ?? '').toString().toLowerCase();
        final spec = (d['specialization'] ?? '').toString().toLowerCase();
        return name.contains(q) || spec.contains(q);
      }).toList();
    });
  }

  Future<void> _loadFavorites() async {
    setState(() {
      isLoading = true;
      favDoctors = [];
      filteredDoctors = [];
    });

    try {
      final String? patientId = _storage.read('userId');
      if (patientId == null || patientId.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final favSnap = await _usersRef.child(patientId).child('favorites').get();

      if (!favSnap.exists || favSnap.value == null) {
        setState(() => isLoading = false);
        return;
      }

      final Map<dynamic, dynamic> favMap =
          Map<dynamic, dynamic>.from(favSnap.value as Map);

      final List<Map<String, dynamic>> list = [];

      for (final doctorId in favMap.keys) {
        final docSnap = await _usersRef.child(doctorId.toString()).get();
        if (!docSnap.exists || docSnap.value == null) continue;

        final data = Map<Object?, Object?>.from(docSnap.value as Map);
        final isDoctor = data['role'] == 'doctor';
        if (!isDoctor) continue;

        list.add({
          'id': doctorId.toString(),
          'name': (data['name'] ?? 'دكتور').toString(),
          'specialization': (data['specialization'] ?? 'غير محدد').toString(),
          'photoUrl': (data['photoUrl'] ??
                  'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop')
              .toString(),
        });
      }

      list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      setState(() {
        favDoctors = list;
        filteredDoctors = list;
        isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('خطأ تحميل المفضلة: $e');
      setState(() {
        favDoctors = [];
        filteredDoctors = [];
        isLoading = false;
      });
    }
  }

  Future<void> _removeFromFavorites(String doctorId) async {
    try {
      final String? patientId = _storage.read('userId');
      if (patientId == null || patientId.isEmpty) return;

      await _usersRef
          .child(patientId)
          .child('favorites')
          .child(doctorId)
          .remove();

      // Update UI فورًا بدون انتظار Reload كامل (أسرع/ألطف)
      setState(() {
        favDoctors.removeWhere((e) => (e['id'] ?? '').toString() == doctorId);
        filteredDoctors
            .removeWhere((e) => (e['id'] ?? '').toString() == doctorId);
      });

      // لو حبيت تضمن التزامن مع DB (اختياري)
      // await _loadFavorites();
    } catch (_) {}
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;

    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'إزالة من المفضلة؟',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم حذف الطبيب من قائمة المفضلة لديك.',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('حذف'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'المفضلة',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'تحديث',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // ✅ Search + Counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'ابحث بالاسم أو التخصص...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${filteredDoctors.length}',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ Content
                  Expanded(
                    child: filteredDoctors.isEmpty
                        ? _EmptyFavoritesState(onRefresh: _loadFavorites)
                        : RefreshIndicator(
                            onRefresh: _loadFavorites,
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: filteredDoctors.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final d = filteredDoctors[index];
                                final doctorId = (d['id'] ?? '').toString();

                                return Dismissible(
                                  key: ValueKey('fav_$doctorId'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    return await _confirmRemove(context);
                                  },
                                  onDismissed: (_) {
                                    _removeFromFavorites(doctorId);
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'حذف',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Icon(Icons.delete_outline,
                                            color: Colors.red),
                                      ],
                                    ),
                                  ),
                                  child: _FavoriteDoctorCard(
                                    name: (d['name'] ?? 'دكتور').toString(),
                                    specialization:
                                        (d['specialization'] ?? 'غير محدد')
                                            .toString(),
                                    photoUrl: (d['photoUrl'] ?? '').toString(),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DoctorDetailsScreen(
                                              doctorId: doctorId),
                                        ),
                                      );
                                    },
                                    onRemove: () async {
                                      final ok = await _confirmRemove(context);
                                      if (!ok) return;
                                      await _removeFromFavorites(doctorId);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FavoriteDoctorCard extends StatelessWidget {
  final String name;
  final String specialization;
  final String photoUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteDoctorCard({
    required this.name,
    required this.specialization,
    required this.photoUrl,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: (() {
                  const fallback =
                      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=1170&auto=format&fit=crop';

                  // ✅ لو الصورة Base64
                  if (photoUrl.trim().startsWith('data:image')) {
                    try {
                      final b64 = photoUrl.split(',').last;
                      final bytes = base64Decode(b64);

                      return Image.memory(
                        bytes,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      );
                    } catch (_) {
                      // لو حصل خطأ نرجع للفولباك
                      return CachedNetworkImage(
                        imageUrl: fallback,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      );
                    }
                  }

                  // ✅ لو الصورة لينك طبيعي
                  return CachedNetworkImage(
                    imageUrl: photoUrl.isNotEmpty ? photoUrl : fallback,
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 62,
                      height: 62,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 62,
                      height: 62,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.person),
                    ),
                  );
                })(),
              ),

              const SizedBox(width: 12),

              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E3A8A),
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
                            specialization,
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
                    const SizedBox(height: 8),

                    // Small badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A8A).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star, size: 16, color: Colors.amber),
                              SizedBox(width: 6),
                              Text(
                                '4.8',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'مفضل',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Remove button
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.red,
                tooltip: 'إزالة',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavoritesState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyFavoritesState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Container(
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.favorite_border,
                  size: 38, color: Colors.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'لا يوجد أطباء في المفضلة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'افتح صفحة أي طبيب واضغط على ❤️ لإضافته هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
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

// شاشة الرئيسية (HomeTab)
// شاشة الرئيسية (HomeTab) — UI Premium
// =======================
// HomeTab (كاملة) + Fix avatarProvider فقط
// =======================
