import 'package:flutter/material.dart';

const Color kTealDark = Color(0xFF0F766E);

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
    if (iso.isNotEmpty) selectedDate = DateTime.tryParse(iso);
  }

  List<String> generateTimeSlots(String rawTime) {
    final raw = rawTime.trim();
    if (raw.isEmpty || raw == 'مغلق') return const [];

    final parsed = _parseScheduleTime(raw);
    if (!parsed.hasRange) return const [];

    final start = _parseArabicTime(parsed.from!);
    final end = _parseArabicTime(parsed.to!);
    if (start == null || end == null) return const [];

    final startMinutes = _minutes(start);
    final endMinutes = _minutes(end);
    if (endMinutes <= startMinutes) return const [];

    final slots = <String>[];
    var currentMinutes = startMinutes;

    // وقت الإغلاق ليس موعد كشف؛ آخر حجز يجب أن يبدأ قبله.
    while (currentMinutes < endMinutes) {
      final time = TimeOfDay(
        hour: (currentMinutes ~/ 60) % 24,
        minute: currentMinutes % 60,
      );

      if (!_isPastSlot(time)) slots.add(_formatTime12Hour(time));
      currentMinutes += 30;
    }

    return slots;
  }

  bool _isPastSlot(TimeOfDay time) {
    if (selectedDate == null) return false;
    final now = DateTime.now();
    final date = selectedDate!;
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (!isToday) return false;

    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return !slotDateTime.isAfter(now);
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  TimeOfDay? _parseArabicTime(String input) {
    var text = input
        .trim()
        .replaceAll('صباحًا', 'ص')
        .replaceAll('صباحا', 'ص')
        .replaceAll('مساءً', 'م')
        .replaceAll('مساءا', 'م')
        .replaceAll('AM', 'ص')
        .replaceAll('PM', 'م')
        .replaceAll('am', 'ص')
        .replaceAll('pm', 'م');

    final isPm = text.contains('م');
    final isAm = text.contains('ص');
    text = text.replaceAll('م', '').replaceAll('ص', '').trim();

    final parts = text.split(':');
    final hour = int.tryParse(parts.first.trim());
    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    var h = hour;
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    return TimeOfDay(hour: h, minute: minute);
  }

  String _formatTime12Hour(TimeOfDay t) {
    var hour = t.hour;
    final period = hour >= 12 ? 'مساءً' : 'صباحًا';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  _ParsedTimeRange _parseScheduleTime(String raw) {
    final s = raw.trim();
    final reg = RegExp(
      r'(\d{1,2}(?::\d{1,2})?\s*(?:صباحًا|صباحا|مساءً|مساءا|ص|م|AM|PM|am|pm)?)',
    );
    final matches = reg
        .allMatches(s)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    if (matches.length >= 2) {
      return _ParsedTimeRange(raw: raw, from: matches[0], to: matches[1]);
    }
    return _ParsedTimeRange(raw: raw);
  }

  @override
  Widget build(BuildContext context) {
    final slots = generateTimeSlots(selectedScheduleTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('اختيار الوقت', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: kTealDark,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                  Text('اليوم المختار: $selectedDay', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 6),
                  if (selectedDate != null)
                    Text(
                      'التاريخ: ${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: slots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('لا توجد مواعيد متاحة في هذا اليوم', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text('اختر يومًا آخر من جدول العيادة.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: slots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final time = slots[i];
                        final selected = selectedSlot == time;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => selectedSlot = time),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected ? kTealDark.withOpacity(0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected ? kTealDark.withOpacity(0.60) : Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, color: selected ? kTealDark : Colors.grey.shade600),
                                const SizedBox(width: 10),
                                Expanded(child: Text(time, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: selected ? kTealDark : Colors.black87))),
                                if (selected) const Icon(Icons.check_circle_rounded, color: kTealDark),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: selectedSlot == null ? null : () => Navigator.pop(context, selectedSlot),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTealDark,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('تأكيد الوقت', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
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
      from != null && from!.trim().isNotEmpty && to != null && to!.trim().isNotEmpty;
}
