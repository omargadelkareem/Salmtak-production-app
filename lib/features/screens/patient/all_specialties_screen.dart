import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'specialty_doctors_screen.dart';

class AllSpecialtiesScreen extends StatefulWidget {
  const AllSpecialtiesScreen({super.key});

  @override
  State<AllSpecialtiesScreen> createState() => _AllSpecialtiesScreenState();
}

class _AllSpecialtiesScreenState extends State<AllSpecialtiesScreen> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF5F7FA);

  final DatabaseReference _usersRef =
      FirebaseDatabase.instance.ref().child('users');
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  Map<String, int> doctorCounts = <String, int>{};

  final List<Map<String, dynamic>> allSpecialties = [
    {'title': 'أسنان', 'icon': Icons.sentiment_satisfied, 'value': 'أسنان'},
    {'title': 'جلدية وتناسلية', 'icon': Icons.face, 'value': 'جلدية وتناسلية'},
    {'title': 'قلب وأوعية دموية', 'icon': Icons.favorite, 'value': 'قلب وأوعية دموية'},
    {'title': 'عظام', 'icon': Icons.healing, 'value': 'عظام'},
    {'title': 'أطفال وحديثي الولادة', 'icon': Icons.child_friendly, 'value': 'أطفال وحديثي الولادة'},
    {'title': 'نساء وتوليد', 'icon': Icons.pregnant_woman, 'value': 'نساء وتوليد'},
    {'title': 'عيون', 'icon': Icons.visibility, 'value': 'عيون'},
    {'title': 'أنف وأذن وحنجرة', 'icon': Icons.hearing, 'value': 'أنف وأذن وحنجرة'},
    {'title': 'مخ وأعصاب', 'icon': Icons.psychology, 'value': 'مخ وأعصاب'},
    {'title': 'جراحة عامة', 'icon': Icons.local_hospital, 'value': 'جراحة عامة'},
    {'title': 'تغذيه', 'icon': Icons.fastfood, 'value': 'تغذيه'},
    {'title': 'الأشعة التداخلية', 'icon': Icons.medical_services, 'value': 'الأشعة التداخلية'},
    {'title': 'الرئة', 'icon': Icons.air, 'value': 'الرئة'},
    {'title': 'أورام', 'icon': Icons.coronavirus, 'value': 'أورام'},
    {'title': 'أورام الثدي', 'icon': Icons.favorite_border, 'value': 'أورام الثدي'},
    {'title': 'أمراض دم', 'icon': Icons.bloodtype, 'value': 'أمراض دم'},
    {'title': 'جهاز هضمي ومناظير', 'icon': Icons.food_bank, 'value': 'جهاز هضمي ومناظير'},
    {'title': 'جراحة أطفال', 'icon': Icons.child_care, 'value': 'جراحة أطفال'},
    {'title': 'جراحة أورام', 'icon': Icons.coronavirus, 'value': 'جراحة أورام'},
    {'title': 'جراحة أوعية دموية', 'icon': Icons.bloodtype, 'value': 'جراحة أوعية دموية'},
    {'title': 'جراحة تجميل', 'icon': Icons.face_retouching_natural, 'value': 'جراحة تجميل'},
    {'title': 'جراحة سمنة ومناظير', 'icon': Icons.monitor_weight, 'value': 'جراحة سمنة ومناظير'},
    {'title': 'جراحة عمود فقري', 'icon': Icons.accessibility_new, 'value': 'جراحة عمود فقري'},
    {'title': 'جراحة قلب وصدر', 'icon': Icons.favorite, 'value': 'جراحة قلب وصدر'},
    {'title': 'جراحة مخ وأعصاب', 'icon': Icons.psychology, 'value': 'جراحة مخ وأعصاب'},
    {'title': 'جراحة الوجه والفكين', 'icon': Icons.face, 'value': 'جراحة الوجه والفكين'},
    {'title': 'حساسية ومناعة', 'icon': Icons.shield, 'value': 'حساسية ومناعة'},
    {'title': 'حقن مجهري وأطفال أنابيب', 'icon': Icons.biotech, 'value': 'حقن مجهري وأطفال أنابيب'},
    {'title': 'ذكورة وعقم', 'icon': Icons.male, 'value': 'ذكورة وعقم'},
    {'title': 'سكّر وغدد صماء', 'icon': Icons.cake, 'value': 'سكّر وغدد صماء'},
    {'title': 'سمعيات', 'icon': Icons.hearing, 'value': 'سمعيات'},
    {'title': 'صدر وجهاز تنفسي', 'icon': Icons.air, 'value': 'صدر وجهاز تنفسي'},
    {'title': 'علاج الإدمان', 'icon': Icons.no_drinks, 'value': 'علاج الإدمان'},
    {'title': 'علاج الآلام', 'icon': Icons.sentiment_very_dissatisfied, 'value': 'علاج الآلام'},
    {'title': 'علاج بالأكسجين', 'icon': Icons.air, 'value': 'علاج بالأكسجين'},
    {'title': 'طب الأسرة', 'icon': Icons.family_restroom, 'value': 'طب الأسرة'},
    {'title': 'طب العام والحساسية', 'icon': Icons.local_hospital, 'value': 'طب العام والحساسية'},
    {'title': 'طب المسنين', 'icon': Icons.elderly, 'value': 'طب المسنين'},
    {'title': 'طب النفسى', 'icon': Icons.psychology, 'value': 'طب النفسى'},
    {'title': 'طب نفسى الأطفال', 'icon': Icons.child_care, 'value': 'طب نفسى الأطفال'},
    {'title': 'طب التجديدي', 'icon': Icons.auto_awesome, 'value': 'طب التجديدي'},
    {'title': 'طب تقويمي', 'icon': Icons.straighten, 'value': 'طب تقويمي'},
    {'title': 'طب النووى', 'icon': Icons.science, 'value': 'طب النووى'},
    {'title': 'كبد', 'icon': Icons.healing, 'value': 'كبد'},
    {'title': 'كُلى', 'icon': Icons.water_drop, 'value': 'كُلى'},
    {'title': 'مراكز أشعة', 'icon': Icons.scanner, 'value': 'مراكز أشعة'},
    {'title': 'مسالك بولية', 'icon': Icons.water_drop, 'value': 'مسالك بولية'},
    {'title': 'معامل تحاليل', 'icon': Icons.biotech, 'value': 'معامل تحاليل'},
    {'title': 'ممارسة عامة', 'icon': Icons.local_hospital, 'value': 'ممارسة عامة'},
    {'title': 'نطق وتخاطب', 'icon': Icons.record_voice_over, 'value': 'نطق وتخاطب'},
  ];

  @override
  void initState() {
    super.initState();
    _loadDoctorCountsInBackground();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _visibleSpecialties {
    final query = _normalize(_searchQuery);
    if (query.isEmpty) return allSpecialties;

    return allSpecialties.where((specialty) {
      final title = _normalize((specialty['title'] ?? '').toString());
      final value = _normalize((specialty['value'] ?? '').toString());
      return title.contains(query) || value.contains(query);
    }).toList();
  }

  Future<void> _loadDoctorCountsInBackground() async {
    try {
      final snapshot = await _usersRef
          .orderByChild('role')
          .equalTo('doctor')
          .get()
          .timeout(const Duration(seconds: 8));

      if (!snapshot.exists || snapshot.value is! Map) return;

      final counts = <String, int>{};
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      for (final value in data.values) {
        if (value is! Map) continue;
        final doctor = Map<dynamic, dynamic>.from(value);
        if (doctor['isApproved'] != true) continue;

        final specialization =
            _normalize((doctor['specialization'] ?? '').toString());
        if (specialization.isEmpty) continue;
        counts[specialization] = (counts[specialization] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() => doctorCounts = counts);
    } catch (_) {
      // لا نوقف الصفحة عند ضعف الإنترنت.
    }
  }

  Future<void> _refreshCounts() async {
    if (mounted) setState(() => doctorCounts = <String, int>{});
    await _loadDoctorCountsInBackground();
  }

  int _countForSpecialty(String value) {
    final normalizedValue = _normalize(value);
    int count = 0;
    for (final entry in doctorCounts.entries) {
      if (entry.key == normalizedValue ||
          entry.key.contains(normalizedValue) ||
          normalizedValue.contains(entry.key)) {
        count += entry.value;
      }
    }
    return count;
  }

  void _openSpecialty(Map<String, dynamic> specialty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpecialtyDoctorsScreen(
          specialtyName: (specialty['title'] ?? '').toString(),
          specialtyId: (specialty['value'] ?? '').toString(),
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSpecialties = _visibleSpecialties;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'اختار التخصص',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCounts,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'احجز مع أفضل دكتور قريب منك',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن تخصص... مثال: اسنان، اطفال، قلب',
                        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _primary, width: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (visibleSpecialties.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 58,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لم نجد هذا التخصص',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'جرّب كتابة اسم آخر أو امسح البحث',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('مسح البحث'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList.separated(
                  itemCount: visibleSpecialties.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final specialty = visibleSpecialties[index];
                    final value = (specialty['value'] ?? '').toString();
                    return _SpecialtyListTile(
                      title: (specialty['title'] ?? '').toString(),
                      icon: specialty['icon'] as IconData,
                      doctorCount: _countForSpecialty(value),
                      onTap: () => _openSpecialty(specialty),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyListTile extends StatelessWidget {
  const _SpecialtyListTile({
    required this.title,
    required this.icon,
    required this.doctorCount,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int doctorCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _AllSpecialtiesScreenState._primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      doctorCount == 0
                          ? 'اعرض الأطباء المتاحين'
                          : '$doctorCount طبيب متاح',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
