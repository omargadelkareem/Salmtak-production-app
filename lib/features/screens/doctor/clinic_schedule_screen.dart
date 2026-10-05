import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ClinicScheduleScreen extends StatefulWidget {
  final String doctorId;
  final int clinicIndex;
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
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  late final List<_DaySchedule> _days;
  bool _loading = true;
  bool _saving = false;

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
    _loadSchedule();
  }

  DatabaseReference get _scheduleRef => _db
      .child('users')
      .child(widget.doctorId)
      .child('clinics')
      .child('${widget.clinicIndex}')
      .child('schedule');

  Future<void> _loadSchedule() async {
    try {
      final snap = await _scheduleRef.get().timeout(const Duration(seconds: 8));
      if (snap.exists && snap.value is Map) {
        final map = Map<dynamic, dynamic>.from(snap.value as Map);
        for (final day in _days) {
          final raw = map[day.key];
          if (raw is! Map) continue;
          final value = Map<dynamic, dynamic>.from(raw);
          final from = _parseTime((value['from'] ?? '').toString());
          final to = _parseTime((value['to'] ?? '').toString());
          if (from != null && to != null && _minutes(to) > _minutes(from)) {
            day.enabled = true;
            day.from = from;
            day.to = to;
          }
        }
      }
    } catch (e) {
      debugPrint('Clinic schedule load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String input) {
    var text = input
        .trim()
        .replaceAll('صباحًا', 'ص')
        .replaceAll('مساءً', 'م')
        .replaceAll('AM', 'ص')
        .replaceAll('PM', 'م');
    final pm = text.contains('م');
    final am = text.contains('ص');
    text = text.replaceAll('م', '').replaceAll('ص', '').trim();
    final parts = text.split(':');
    final h0 = int.tryParse(parts.first.trim());
    final m = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
    if (h0 == null || m == null || m < 0 || m > 59) return null;
    var h = h0;
    if (pm && h < 12) h += 12;
    if (am && h == 12) h = 0;
    if (h < 0 || h > 23) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _format(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final p = t.period == DayPeriod.am ? 'ص' : 'م';
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $p';
  }

  bool get _valid {
    final enabled = _days.where((d) => d.enabled).toList();
    if (enabled.isEmpty) return false;
    return enabled.every((d) => d.from != null && d.to != null && _minutes(d.to!) > _minutes(d.from!));
  }

  Future<void> _pickTime(_DaySchedule day, {required bool from}) async {
    final initial = from ? day.from : day.to;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? (from ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 17, minute: 0)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        day.from = picked;
        if (day.to != null && _minutes(day.to!) <= _minutes(picked)) day.to = null;
      } else {
        day.to = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فعّل يومًا واحدًا على الأقل وحدد وقت بداية ونهاية صحيح.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{};
      for (final day in _days) {
        if (!day.enabled) continue;
        data[day.key] = {'from': _format(day.from!), 'to': _format(day.to!)};
      }
      await _scheduleRef.set(data);
      if (!mounted) return;
      if (widget.clinicIndex + 1 < widget.clinicsCount) {
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ مواعيد العيادة بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ المواعيد. حاول مرة أخرى.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F9),
      appBar: AppBar(
        title: Text('مواعيد العيادة ${widget.clinicIndex + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
                    child: const Text('فعّل أيام العمل وحدد بداية ونهاية الدوام. المواعيد المتاحة للمريض تُنشأ كل 30 دقيقة.', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _days.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final day = _days[i];
                      final invalid = day.enabled && day.from != null && day.to != null && _minutes(day.to!) <= _minutes(day.from!);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: day.enabled ? color.withOpacity(.45) : const Color(0xFFE5E7EB))),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: Text(day.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                              Switch(value: day.enabled, activeColor: color, onChanged: (v) => setState(() { day.enabled = v; if (!v) { day.from = null; day.to = null; } })),
                            ]),
                            if (day.enabled) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: _TimeButton(label: 'من', value: day.from == null ? 'اختر' : _format(day.from!), color: color, onTap: () => _pickTime(day, from: true))),
                                const SizedBox(width: 10),
                                Expanded(child: _TimeButton(label: 'إلى', value: day.to == null ? 'اختر' : _format(day.to!), color: color, onTap: () => _pickTime(day, from: false))),
                              ]),
                              if (invalid) const Padding(padding: EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerRight, child: Text('وقت النهاية يجب أن يكون بعد وقت البداية', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)))),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(widget.clinicIndex + 1 < widget.clinicsCount ? 'حفظ والانتقال للعيادة التالية' : 'حفظ المواعيد', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DaySchedule {
  final String title;
  final String key;
  bool enabled = false;
  TimeOfDay? from;
  TimeOfDay? to;
  _DaySchedule(this.title, this.key);
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: color.withOpacity(.35)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Column(children: [Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)), const SizedBox(height: 3), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900))]),
    );
  }
}
