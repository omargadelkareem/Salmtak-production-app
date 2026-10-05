import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ClinicScheduleScreen extends StatefulWidget {
  final String doctorId;

  /// ✅ 0 = العيادة الأولى / 1 = العيادة الثانية
  final int clinicIndex;

  /// ✅ عدد العيادات (1 أو 2)
  final int clinicsCount;

  final Color primaryColor;

  const ClinicScheduleScreen({
    super.key,
    required this.doctorId,
    required this.clinicIndex,
    required this.clinicsCount,
    required this.primaryColor,
  });

  @override
  State<ClinicScheduleScreen> createState() => _ClinicScheduleScreenState();
}

class _ClinicScheduleScreenState extends State<ClinicScheduleScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  bool _saving = false;

  late final List<_DaySchedule> _days;

  @override
  void initState() {
    super.initState();

    _days = [
      _DaySchedule('السبت', 'sat'),
      _DaySchedule('الأحد', 'sun'),
      _DaySchedule('الإثنين', 'mon'),
      _DaySchedule('الثلاثاء', 'tue'),
      _DaySchedule('الأربعاء', 'wed'),
      _DaySchedule('الخميس', 'thu'),
      _DaySchedule('الجمعة', 'fri'),
    ];
  }

  String get _clinicTitle => widget.clinicIndex == 0
      ? 'مواعيد العيادة الأولى'
      : 'مواعيد العيادة الثانية';

  // ==========================
  // ✅ Helpers
  // ==========================
  TimeOfDay? _toTimeOfDay(int? h12, int? m, DayPeriod? p) {
    if (h12 == null || m == null || p == null) return null;

    int hour = h12 % 12; // 12 -> 0
    if (p == DayPeriod.pm) hour += 12;

    return TimeOfDay(hour: hour, minute: m);
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _formatTimeArabic(TimeOfDay t) {
    final hour12 = (t.hourOfPeriod == 0) ? 12 : t.hourOfPeriod;
    final h = hour12.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'ص' : 'م';
    return '$h:$m $period';
  }

  bool _validSchedule() {
    final enabledDays = _days.where((d) => d.enabled).toList();
    if (enabledDays.isEmpty) return false;

    for (final d in enabledDays) {
      final from = _toTimeOfDay(d.fromHour, d.fromMinute, d.fromPeriod);
      final to = _toTimeOfDay(d.toHour, d.toMinute, d.toPeriod);

      if (from == null || to == null) return false;
      if (_toMinutes(to) <= _toMinutes(from)) return false;
    }

    return true;
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.black87,
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (!_validSchedule()) {
      _toast(
        'من فضلك فعّل يوم واحد على الأقل واختر وقت صحيح (من < إلى)',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final Map<String, dynamic> scheduleMap = {};

      for (final d in _days) {
        if (!d.enabled) continue;

        final from = _toTimeOfDay(d.fromHour, d.fromMinute, d.fromPeriod)!;
        final to = _toTimeOfDay(d.toHour, d.toMinute, d.toPeriod)!;

        scheduleMap[d.key] = {
          'from': _formatTimeArabic(from),
          'to': _formatTimeArabic(to),
        };
      }

      await _dbRef
          .child('users')
          .child(widget.doctorId)
          .child('clinics')
          .child('${widget.clinicIndex}')
          .child('schedule')
          .set(scheduleMap);

      // ✅ لو في عيادة ثانية -> ينقله ليها بعد حفظ الأولى
      if (widget.clinicIndex + 1 < widget.clinicsCount) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ClinicScheduleScreen(
              doctorId: widget.doctorId,
              clinicIndex: widget.clinicIndex + 1,
              clinicsCount: widget.clinicsCount,
              primaryColor: widget.primaryColor,
            ),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم حفظ مواعيد العيادات بنجاح ✅'),
            backgroundColor: Colors.green.shade700,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      _toast('حدث خطأ أثناء الحفظ: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ==========================
  // ✅ UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _clinicTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Text(
                'فعّل الأيام المتاحة ثم اختار الوقت بسهولة (ساعة + دقيقة + ص/م) ✅',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final d = _days[i];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: d.enabled ? color : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Switch(
                              value: d.enabled,
                              activeColor: color,
                              onChanged: (v) {
                                setState(() {
                                  d.enabled = v;
                                  if (!v) {
                                    d.reset();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (d.enabled) ...[
                          const SizedBox(height: 10),

                          // ✅ From / To selectors
                          Row(
                            children: [
                              Expanded(
                                child: _TimeSelectorCard(
                                  title: 'من',
                                  primary: color,
                                  hour: d.fromHour,
                                  minute: d.fromMinute,
                                  period: d.fromPeriod,
                                  onChanged: (h, m, p) {
                                    setState(() {
                                      d.fromHour = h;
                                      d.fromMinute = m;
                                      d.fromPeriod = p;

                                      // ✅ لو "إلى" أقل -> نصفرها تلقائيًا
                                      final from = _toTimeOfDay(d.fromHour,
                                          d.fromMinute, d.fromPeriod);
                                      final to = _toTimeOfDay(
                                          d.toHour, d.toMinute, d.toPeriod);

                                      if (from != null && to != null) {
                                        if (_toMinutes(to) <=
                                            _toMinutes(from)) {
                                          d.toHour = null;
                                          d.toMinute = null;
                                          d.toPeriod = null;
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TimeSelectorCard(
                                  title: 'إلى',
                                  primary: color,
                                  hour: d.toHour,
                                  minute: d.toMinute,
                                  period: d.toPeriod,
                                  onChanged: (h, m, p) {
                                    setState(() {
                                      d.toHour = h;
                                      d.toMinute = m;
                                      d.toPeriod = p;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ✅ Validation message
                          Builder(builder: (_) {
                            final from = _toTimeOfDay(
                                d.fromHour, d.fromMinute, d.fromPeriod);
                            final to =
                                _toTimeOfDay(d.toHour, d.toMinute, d.toPeriod);

                            if (from == null || to == null) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'اختر وقت "من" و "إلى"',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            }

                            if (_toMinutes(to) <= _toMinutes(from)) {
                              return const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'لازم وقت "إلى" يكون أكبر من "من"',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            }

                            return Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: cs.primary.withOpacity(0.20)),
                                ),
                                child: Text(
                                  '✅ ${_formatTimeArabic(from)} → ${_formatTimeArabic(to)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: cs.primary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        widget.clinicIndex + 1 < widget.clinicsCount
                            ? 'حفظ والانتقال للعيادة التالية'
                            : 'حفظ المواعيد',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySchedule {
  final String title;
  final String key;
  bool enabled = false;

  int? fromHour;
  int? fromMinute;
  DayPeriod? fromPeriod;

  int? toHour;
  int? toMinute;
  DayPeriod? toPeriod;

  _DaySchedule(this.title, this.key);

  void reset() {
    fromHour = null;
    fromMinute = null;
    fromPeriod = null;
    toHour = null;
    toMinute = null;
    toPeriod = null;
  }
}

class _TimeSelectorCard extends StatelessWidget {
  final String title;
  final Color primary;

  final int? hour; // 1..12
  final int? minute; // 0 / 30
  final DayPeriod? period; // am / pm

  final void Function(int? hour, int? minute, DayPeriod? period) onChanged;

  const _TimeSelectorCard({
    required this.title,
    required this.primary,
    required this.hour,
    required this.minute,
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: primary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),

          // ✅ Hour + Minute
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: hour,
                  items: List.generate(12, (i) => i + 1)
                      .map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(h.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                          ))
                      .toList(),
                  onChanged: (v) => onChanged(v, minute, period),
                  decoration: InputDecoration(
                    hintText: 'ساعة',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.35)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: minute,
                  items: const [0, 30]
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.toString().padLeft(2, '0'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => onChanged(hour, v, period),
                  decoration: InputDecoration(
                    hintText: 'دقيقة',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.35)),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ✅ AM / PM Toggle
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                _PeriodButton(
                  title: 'ص',
                  selected: period == DayPeriod.am,
                  primary: primary,
                  onTap: () => onChanged(hour, minute, DayPeriod.am),
                ),
                const SizedBox(width: 8),
                _PeriodButton(
                  title: 'م',
                  selected: period == DayPeriod.pm,
                  primary: primary,
                  onTap: () => onChanged(hour, minute, DayPeriod.pm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String title;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _PeriodButton({
    required this.title,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? primary.withOpacity(0.40)
                  : cs.outlineVariant.withOpacity(0.35),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: selected ? primary : cs.onSurface.withOpacity(0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
