import 'package:flutter/material.dart';

class CompleteBookingScreen extends StatelessWidget {
  final Map<String, dynamic> doctor;

  const CompleteBookingScreen({
    super.key,
    required this.doctor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final selectedDay = (doctor['selectedDay'] ?? '').toString();
    final selectedSlot = (doctor['selectedSlot'] ?? '').toString();
    final selectedDateIso = (doctor['selectedDateIso'] ?? '').toString();
    final name = (doctor['name'] ?? 'دكتور').toString();

    DateTime? date;
    if (selectedDateIso.isNotEmpty) {
      date = DateTime.tryParse(selectedDateIso);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("استكمال الحجز"),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "✅ بيانات الحجز",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 14),
            _RowInfo(title: "الطبيب", value: name),
            _RowInfo(title: "اليوم", value: selectedDay),
            _RowInfo(
              title: "التاريخ",
              value:
                  date == null ? "-" : "${date.year}/${date.month}/${date.day}",
            ),
            _RowInfo(title: "الوقت", value: selectedSlot),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ هنا بقى انت تكمل:
                  // 1) تدخل بيانات المريض
                  // 2) تحفظ الحجز في Firebase
                  // 3) تعمل تأكيد نهائي
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("نكمل باقي خطوات الحجز هنا ✅")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "تأكيد الحجز النهائي",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String title;
  final String value;

  const _RowInfo({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Text(
              "$title: ",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.75),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
