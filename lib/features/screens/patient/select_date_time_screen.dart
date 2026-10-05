import 'package:flutter/material.dart';

const Color kTealDark = Color(0xFF0F766E); // لون الزر

class SelectDateTimeScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final bool lockDate;

  const SelectDateTimeScreen({
    super.key,
    required this.doctor,
    this.lockDate = false,
  });

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen> {
  DateTime? selectedDate;
  String selectedDay = '';
  String selectedScheduleTime = '';
  String? selectedSlot;

  @override
  void initState() {
    super.initState();

    final iso = (widget.doctor['selectedDateIso'] ?? '').toString();
    selectedDay = (widget.doctor['selectedDay'] ?? '').toString();
    selectedScheduleTime = (widget.doctor['selectedTime'] ?? '').toString();

    if (iso.isNotEmpty) {
      selectedDate = DateTime.tryParse(iso);
    }
  }

  // توليد المواعيد بنظام 12 ساعة + صباحًا / مساءً
  List<String> generateTimeSlots(String rawTime) {
    if (rawTime.trim().isEmpty) {
      return ['05:00 صباحًا', '05:30 صباحًا', '06:00 صباحًا'];
    }

    final parsed = _parseScheduleTime(rawTime);
    if (!parsed.hasRange) {
      return [rawTime];
    }

    final start = _parseArabicTime(parsed.from!);
    final end = _parseArabicTime(parsed.to!);

    if (start == null || end == null) {
      return [rawTime];
    }

    final slots = <String>[];
    var current = start;

    while (_compareTime(current, end) <= 0) {
      slots.add(_formatTime12Hour(current));
      current = _addMinutes(current, 30);
    }

    return slots;
  }

  TimeOfDay? _parseArabicTime(String s) {
    var text = s.trim();

    final isPM = text.contains('م');
    final isAM = text.contains('ص');

    text = text.replaceAll('م', '').replaceAll('ص', '').trim();

    int hour = 0;
    int minute = 0;

    if (text.contains(':')) {
      final parts = text.split(':');
      hour = int.tryParse(parts[0].trim()) ?? 0;
      minute = int.tryParse(parts[1].trim()) ?? 0;
    } else {
      hour = int.tryParse(text) ?? 0;
      minute = 0;
    }

    // تحويل إلى نظام 24 ساعة داخليًا
    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  TimeOfDay _addMinutes(TimeOfDay t, int minutes) {
    final total = t.hour * 60 + t.minute + minutes;
    final h = (total ~/ 60) % 24;
    final m = total % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  int _compareTime(TimeOfDay a, TimeOfDay b) {
    final aa = a.hour * 60 + a.minute;
    final bb = b.hour * 60 + b.minute;
    return aa.compareTo(bb);
  }

  // تنسيق الوقت بنظام 12 ساعة + صباحًا / مساءً
  String _formatTime12Hour(TimeOfDay t) {
    int hour = t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    String period = 'صباحًا';

    if (hour >= 12) {
      period = 'مساءً';
      if (hour > 12) hour -= 12;
    }
    if (hour == 0) hour = 12;

    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  _ParsedTimeRange _parseScheduleTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return _ParsedTimeRange(raw: raw);

    final reg = RegExp(r'(\d{1,2}(?::\d{2})?\s*(?:ص|م)?)');
    final matches = reg.allMatches(s).map((m) => m.group(1)!.trim()).toList();

    if (matches.length >= 2) {
      return _ParsedTimeRange(raw: raw, from: matches[0], to: matches[1]);
    }

    if (s.contains('-')) {
      final parts =
          s.split('-').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        return _ParsedTimeRange(raw: raw, from: parts[0], to: parts[1]);
      }
    }

    return _ParsedTimeRange(raw: raw);
  }

  @override
  Widget build(BuildContext context) {
    final slots = generateTimeSlots(selectedScheduleTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'اختيار الوقت',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kTealDark,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اليوم المختار: $selectedDay',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedDate == null
                        ? ''
                        : 'التاريخ: ${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Slots
            Expanded(
              child: ListView.builder(
                itemCount: slots.length,
                itemBuilder: (context, i) {
                  final t = slots[i];
                  final selected = selectedSlot == t;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => selectedSlot = t),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? kTealDark.withOpacity(0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? kTealDark.withOpacity(0.60)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color:
                                  selected ? kTealDark : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: selected ? kTealDark : Colors.black87,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: kTealDark),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Confirm Button - Teal Dark
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: selectedSlot == null
                    ? null
                    : () {
                        Navigator.pop(context, selectedSlot);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTealDark,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'تأكيد الوقت',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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

class _ParsedTimeRange {
  final String? from;
  final String? to;
  final String raw;

  const _ParsedTimeRange({required this.raw, this.from, this.to});

  bool get hasRange =>
      (from != null && from!.trim().isNotEmpty) &&
      (to != null && to!.trim().isNotEmpty);
}
