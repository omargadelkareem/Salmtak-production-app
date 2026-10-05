import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole; // null | 'patient' | 'doctor'

  static const Color tealDark = Color(0xFF0F766E); // Teal Dark
  static const Color teal = Color(0xFF14B8A6); // Teal
  static const Color tealSoft = Color(0xFF99F6E4); // Teal Soft

  void _selectRole(String role) {
    setState(() => selectedRole = role);
  }

  void _confirmSelection() {
    if (selectedRole == null) return;

    Navigator.pushNamed(
      context,
      '/auth',
      arguments: selectedRole,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F8),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxHeight < 720;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 10 : 16,
                  16,
                  24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 20 : 32),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (canPop)
                            _TopIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            )
                          else
                            const SizedBox(width: 44),
                          const Spacer(),
                          const Text(
                            'اختيار نوع الحساب',
                            style: TextStyle(
                              color: Color(0xFF1F363C),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 44),
                        ],
                      ),
                      SizedBox(height: compact ? 14 : 24),
                      _MedicalHeroCard(
                        compact: compact,
                        tealDark: tealDark,
                        teal: teal,
                      ),
                      SizedBox(height: compact ? 16 : 24),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'كيف تريد استخدام سلامتك؟',
                          style: TextStyle(
                            color: Color(0xFF12343B),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'يمكنك اختيار نوع الحساب المناسب ثم المتابعة',
                          style: TextStyle(
                            color: Color(0xFF71838A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleCard(
                              title: 'طبيب',
                              subtitle: 'إدارة العيادات والمواعيد والحجوزات',
                              icon: Icons.medical_services_rounded,
                              badge: 'للأطباء',
                              active: selectedRole == 'doctor',
                              accent: const Color(0xFF0F766E),
                              onTap: () => _selectRole('doctor'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _RoleCard(
                              title: 'مستخدم',
                              subtitle: 'البحث عن طبيب وحجز موعد بسهولة',
                              icon: Icons.person_rounded,
                              badge: 'للحجز',
                              active: selectedRole == 'patient',
                              accent: const Color(0xFF2563EB),
                              onTap: () => _selectRole('patient'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selectedRole == null
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: selectedRole == null
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF99F6E4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedRole == null
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: selectedRole == null
                                  ? const Color(0xFF64748B)
                                  : tealDark,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedRole == null
                                    ? 'اختر نوع الحساب للمتابعة'
                                    : selectedRole == 'doctor'
                                        ? 'تم اختيار حساب طبيب'
                                        : 'تم اختيار حساب مستخدم',
                                style: TextStyle(
                                  color: selectedRole == null
                                      ? const Color(0xFF64748B)
                                      : tealDark,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              selectedRole == null ? null : _confirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealDark,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'متابعة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Color(0xFF94A3B8),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'بياناتك محفوظة وآمنة داخل التطبيق',
                            style: TextStyle(
                              color: Color(0xFF7A8B92),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =======================
// Components
// =======================

class _MedicalHeroCard extends StatelessWidget {
  const _MedicalHeroCard({
    required this.compact,
    required this.tealDark,
    required this.teal,
  });

  final bool compact;
  final Color tealDark;
  final Color teal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [tealDark, teal],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: tealDark.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -55,
            end: -35,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -70,
            start: -45,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: compact ? 68 : 76,
                height: compact ? 68 : 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'سلامتك',
                      style: TextStyle(
                        color: Color(0xFFCCFBF1),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'رعاية طبية أقرب وأسهل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'اختر نوع حسابك وابدأ تجربة طبية منظمة وآمنة',
                      style: TextStyle(
                        color: Color(0xFFD9FFFA),
                        fontSize: 10.8,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: 210,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: active ? accent : const Color(0xFFE3EAEC),
              width: active ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: active
                    ? accent.withOpacity(0.15)
                    : const Color(0xFF0F172A).withOpacity(0.045),
                blurRadius: active ? 24 : 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent, size: 25),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? accent : Colors.white,
                      border: Border.all(
                        color: active ? accent : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: active
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF172B31),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF71838A),
                  fontSize: 10.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF0F766E)),
        ),
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
