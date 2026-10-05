import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

class AppointmentsTab extends StatefulWidget {
  const AppointmentsTab({super.key});

  @override
  State<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<AppointmentsTab> {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _background = Color(0xFFF7F9FC);
  static const Color _text = Color(0xFF172033);
  static const Color _muted = Color(0xFF7B8494);

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();

  bool _isLoading = true;
  bool _isDeleting = false;
  String _selectedFilter = 'all';

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  int _safePrice(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(String value) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  String _formatFullDate(String value) {
    final parsedDate = _parseDate(value);
    if (parsedDate == null) return value.isEmpty ? 'غير محدد' : value;

    final day = DateFormat('EEEE', 'ar').format(parsedDate);
    final date = DateFormat('d MMMM yyyy', 'ar').format(parsedDate);
    return '$day، $date';
  }

  String _formatDayNumber(String value) {
    final parsedDate = _parseDate(value);
    if (parsedDate == null) return '--';
    return DateFormat('dd', 'ar').format(parsedDate);
  }

  String _formatMonth(String value) {
    final parsedDate = _parseDate(value);
    if (parsedDate == null) return 'موعد';
    return DateFormat('MMM', 'ar').format(parsedDate);
  }

  String _statusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'تم التأكيد';
      case 'cancelled':
        return 'ملغي';
      case 'completed':
        return 'مكتمل';
      default:
        return 'قيد التأكيد';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF16865C);
      case 'cancelled':
        return const Color(0xFFD64545);
      case 'completed':
        return const Color(0xFF4766C7);
      default:
        return const Color(0xFFE68A17);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  String _paymentText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع';
      case 'pending':
        return 'قيد المراجعة';
      default:
        return 'غير مدفوع';
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF16865C);
      case 'pending':
        return const Color(0xFFE68A17);
      default:
        return const Color(0xFFD64545);
    }
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final patientId = _storage.read<String>('userId');
      if (patientId == null || patientId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _appointments = [];
          _filteredAppointments = [];
          _isLoading = false;
        });
        return;
      }

      final idsSnapshot = await _database
          .child('users')
          .child(patientId)
          .child('myAppointments')
          .get();

      if (!idsSnapshot.exists || idsSnapshot.value == null) {
        if (!mounted) return;
        setState(() {
          _appointments = [];
          _filteredAppointments = [];
          _isLoading = false;
        });
        return;
      }

      final idsMap = Map<dynamic, dynamic>.from(idsSnapshot.value as Map);
      final futures = idsMap.keys.map((rawId) async {
        final appointmentId = rawId.toString();
        final snapshot = await _database
            .child('appointments')
            .child(patientId)
            .child(appointmentId)
            .get();

        if (!snapshot.exists || snapshot.value == null) return null;

        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        return <String, dynamic>{
          'id': appointmentId,
          'doctorName': (data['doctorName'] ?? 'دكتور').toString(),
          'specialization':
              (data['specialization'] ?? 'تخصص غير محدد').toString(),
          'doctorPhotoUrl': (data['doctorPhotoUrl'] ?? '').toString(),
          'date': (data['date'] ?? '').toString(),
          'time': (data['time'] ?? '').toString(),
          'price': _safePrice(data['appointmentPrice'] ?? data['price']),
          'status': (data['status'] ?? 'pending').toString(),
          'paymentMethod': (data['paymentMethod'] ?? 'clinic').toString(),
          'paymentStatus': (data['paymentStatus'] ?? 'unpaid').toString(),
          'clinicAddress': (data['clinicAddress'] ?? '').toString(),
        };
      }).toList();

      final loaded = (await Future.wait(futures))
          .whereType<Map<String, dynamic>>()
          .toList();

      loaded.sort((a, b) {
        final first = '${a['date']} ${a['time']}';
        final second = '${b['date']} ${b['time']}';
        return second.compareTo(first);
      });

      if (!mounted) return;
      setState(() {
        _appointments = loaded;
        _applyFilter(notify: false);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Appointments loading error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      setState(() {
        _appointments = [];
        _filteredAppointments = [];
        _isLoading = false;
      });

      _showSnackBar('تعذر تحميل المواعيد. حاول مرة أخرى.');
    }
  }

  void _applyFilter({bool notify = true}) {
    if (_selectedFilter == 'all') {
      _filteredAppointments = List<Map<String, dynamic>>.from(_appointments);
    } else {
      _filteredAppointments = _appointments
          .where((item) => item['status']?.toString() == _selectedFilter)
          .toList();
    }

    if (notify && mounted) setState(() {});
  }

  void _changeFilter(String value) {
    setState(() {
      _selectedFilter = value;
      _applyFilter(notify: false);
    });
  }

  Future<bool> _confirmDelete(Map<String, dynamic> appointment) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E8EF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEEEE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 32,
                    color: Color(0xFFD64545),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'حذف الموعد؟',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم حذف موعد ${appointment['doctorName']} نهائيًا من حسابك، ولا يمكن التراجع عن هذه الخطوة.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    height: 1.7,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: _text,
                          side: const BorderSide(color: Color(0xFFE1E6ED)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'تراجع',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.delete_rounded, size: 20),
                        label: const Text('حذف'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFFD64545),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteAppointment(Map<String, dynamic> appointment) async {
    if (_isDeleting) return;

    final patientId = _storage.read<String>('userId');
    final appointmentId = appointment['id']?.toString() ?? '';

    if (patientId == null || patientId.isEmpty || appointmentId.isEmpty) {
      _showSnackBar('تعذر تحديد الموعد المطلوب.');
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final updates = <String, dynamic>{
        'appointments/$patientId/$appointmentId': null,
        'users/$patientId/myAppointments/$appointmentId': null,
      };

      await _database.update(updates);

      if (!mounted) return;
      setState(() {
        _appointments.removeWhere((item) => item['id'] == appointmentId);
        _applyFilter(notify: false);
        _isDeleting = false;
      });

      _showSnackBar('تم حذف الموعد بنجاح.');
    } catch (error) {
      debugPrint('Appointment delete error: $error');
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showSnackBar('تعذر حذف الموعد. حاول مرة أخرى.');
    }
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final patientId = _storage.read<String>('userId');
    final appointmentId = appointment['id']?.toString() ?? '';

    if (patientId == null || patientId.isEmpty || appointmentId.isEmpty) return;

    try {
      await _database
          .child('appointments')
          .child(patientId)
          .child(appointmentId)
          .update({'status': 'cancelled'});

      if (!mounted) return;
      setState(() {
        final index = _appointments.indexWhere(
          (item) => item['id'] == appointmentId,
        );
        if (index != -1) _appointments[index]['status'] = 'cancelled';
        _applyFilter(notify: false);
      });

      _showSnackBar('تم إلغاء الموعد.');
    } catch (error) {
      debugPrint('Appointment cancellation error: $error');
      _showSnackBar('تعذر إلغاء الموعد.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 20,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مواعيدي',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'تابع مواعيدك وحالة الحجز',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: IconButton.filledTonal(
                onPressed: _loadAppointments,
                tooltip: 'تحديث المواعيد',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primary,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const _AppointmentsLoading()
            : Column(
                children: [
                  _buildFilters(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _filteredAppointments.isEmpty
                        ? _EmptyAppointments(
                            isAll: _selectedFilter == 'all',
                            onRefresh: _loadAppointments,
                          )
                        : RefreshIndicator(
                            color: _primary,
                            onRefresh: _loadAppointments,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 120),
                              itemCount: _filteredAppointments.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final appointment =
                                    _filteredAppointments[index];
                                final status =
                                    appointment['status']?.toString() ??
                                        'pending';

                                return TweenAnimationBuilder<double>(
                                  duration: Duration(
                                    milliseconds: 260 + (index * 45),
                                  ),
                                  tween: Tween(begin: 0, end: 1),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Dismissible(
                                    key: ValueKey(
                                      'appointment_${appointment['id']}',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) =>
                                        _confirmDelete(appointment),
                                    onDismissed: (_) =>
                                        _deleteAppointment(appointment),
                                    background: _DeleteBackground(
                                      borderRadius: 24,
                                    ),
                                    child: _ProfessionalAppointmentCard(
                                      appointment: appointment,
                                      formattedDate: _formatFullDate(
                                        appointment['date']?.toString() ?? '',
                                      ),
                                      dayNumber: _formatDayNumber(
                                        appointment['date']?.toString() ?? '',
                                      ),
                                      monthText: _formatMonth(
                                        appointment['date']?.toString() ?? '',
                                      ),
                                      statusText: _statusText(status),
                                      statusColor: _statusColor(status),
                                      statusIcon: _statusIcon(status),
                                      paymentText: _paymentText(
                                        appointment['paymentStatus']
                                                ?.toString() ??
                                            'unpaid',
                                      ),
                                      paymentColor: _paymentColor(
                                        appointment['paymentStatus']
                                                ?.toString() ??
                                            'unpaid',
                                      ),
                                      onDelete: () async {
                                        final confirmed =
                                            await _confirmDelete(appointment);
                                        if (confirmed) {
                                          await _deleteAppointment(appointment);
                                        }
                                      },
                                      onCancel: status == 'pending' ||
                                              status == 'confirmed'
                                          ? () =>
                                              _cancelAppointment(appointment)
                                          : null,
                                    ),
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

  // Widget _buildOverview() {
  //   final confirmed = _appointments
  //       .where((item) => item['status']?.toString() == 'confirmed')
  //       .length;
  //   final pending = _appointments
  //       .where((item) => item['status']?.toString() == 'pending')
  //       .length;

  //   return Container(
  //     margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
  //     padding: const EdgeInsets.all(18),
  //     decoration: BoxDecoration(
  //       gradient: const LinearGradient(
  //         begin: Alignment.topRight,
  //         end: Alignment.bottomLeft,
  //         colors: [Color(0xFF0F766E), Color(0xFF149588)],
  //       ),
  //       borderRadius: BorderRadius.circular(26),
  //       boxShadow: [
  //         BoxShadow(
  //           color: _primary.withOpacity(0.22),
  //           blurRadius: 24,
  //           offset: const Offset(0, 12),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               const Text(
  //                 'إجمالي مواعيدك',
  //                 style: TextStyle(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w700,
  //                   color: Color(0xFFD9F6F2),
  //                 ),
  //               ),
  //               const SizedBox(height: 5),
  //               Text(
  //                 '${_appointments.length} موعد',
  //                 style: const TextStyle(
  //                   fontSize: 27,
  //                   fontWeight: FontWeight.w900,
  //                   color: Colors.white,
  //                 ),
  //               ),
  //               const SizedBox(height: 14),
  //               Row(
  //                 children: [
  //                   _OverviewBadge(
  //                     icon: Icons.verified_rounded,
  //                     text: '$confirmed مؤكد',
  //                   ),
  //                   const SizedBox(width: 8),
  //                   _OverviewBadge(
  //                     icon: Icons.schedule_rounded,
  //                     text: '$pending انتظار',
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         Container(
  //           width: 78,
  //           height: 78,
  //           decoration: BoxDecoration(
  //             color: Colors.white.withOpacity(0.15),
  //             borderRadius: BorderRadius.circular(24),
  //             border: Border.all(color: Colors.white.withOpacity(0.18)),
  //           ),
  //           child: const Icon(
  //             Icons.calendar_month_rounded,
  //             size: 40,
  //             color: Colors.white,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildFilters() {
    const filters = [
      ('all', 'الكل'),
      ('pending', 'قيد التأكيد'),
      ('confirmed', 'المؤكدة'),
      ('cancelled', 'الملغاة'),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final selected = _selectedFilter == item.$1;
          final count = item.$1 == 'all'
              ? _appointments.length
              : _appointments
                  .where((e) => e['status']?.toString() == item.$1)
                  .length;

          return InkWell(
            onTap: () => _changeFilter(item.$1),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _primary : const Color(0xFFE4E8EF),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : _text,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.18)
                          : const Color(0xFFF0F3F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : _muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfessionalAppointmentCard extends StatelessWidget {
  static const Color _primary = Color(0xFF0F766E);
  static const Color _text = Color(0xFF172033);
  static const Color _muted = Color(0xFF7B8494);

  const _ProfessionalAppointmentCard({
    required this.appointment,
    required this.formattedDate,
    required this.dayNumber,
    required this.monthText,
    required this.statusText,
    required this.statusColor,
    required this.statusIcon,
    required this.paymentText,
    required this.paymentColor,
    required this.onDelete,
    this.onCancel,
  });

  final Map<String, dynamic> appointment;
  final String formattedDate;
  final String dayNumber;
  final String monthText;
  final String statusText;
  final Color statusColor;
  final IconData statusIcon;
  final String paymentText;
  final Color paymentColor;
  final VoidCallback onDelete;
  final VoidCallback? onCancel;

  ImageProvider? _imageProvider(String value) {
    if (value.trim().isEmpty) return null;

    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(value.split(',').last));
      } catch (_) {
        return null;
      }
    }

    return NetworkImage(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = appointment['doctorName']?.toString() ?? 'دكتور';
    final specialization =
        appointment['specialization']?.toString() ?? 'تخصص غير محدد';
    final photo = appointment['doctorPhotoUrl']?.toString() ?? '';
    final time = appointment['time']?.toString() ?? 'غير محدد';
    final price = appointment['price'] ?? 0;
    final paymentMethod = appointment['paymentMethod']?.toString() == 'wallet'
        ? 'المحفظة'
        : 'داخل العيادة';
    final clinicAddress = appointment['clinicAddress']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EAF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172033).withOpacity(0.055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNumber,
                        style: const TextStyle(
                          fontSize: 23,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        monthText,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: _primary.withOpacity(0.20),
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFFE8F8F6),
                              backgroundImage: _imageProvider(photo),
                              onBackgroundImageError: (_, __) {},
                              child: _imageProvider(photo) == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      color: _primary,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: _text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  specialization,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'خيارات الموعد',
                            color: Colors.white,
                            surfaceTintColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onSelected: (value) {
                              if (value == 'delete') onDelete();
                              if (value == 'cancel') onCancel?.call();
                            },
                            itemBuilder: (_) => [
                              if (onCancel != null)
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.event_busy_rounded,
                                        color: Color(0xFFE68A17),
                                      ),
                                      SizedBox(width: 10),
                                      Text('إلغاء الموعد'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      color: Color(0xFFD64545),
                                    ),
                                    SizedBox(width: 10),
                                    Text('حذف الكارت'),
                                  ],
                                ),
                              ),
                            ],
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.more_vert_rounded,
                                color: _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      _StatusBadge(
                        icon: statusIcon,
                        text: statusText,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            color: const Color(0xFFF0F2F6),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
            child: Column(
              children: [
                _AppointmentInfoRow(
                  icon: Icons.calendar_today_rounded,
                  title: 'التاريخ',
                  value: formattedDate,
                ),
                const SizedBox(height: 12),
                _AppointmentInfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'الوقت',
                  value: time.isEmpty ? 'غير محدد' : time,
                ),
                const SizedBox(height: 12),
                _AppointmentInfoRow(
                  icon: Icons.payments_outlined,
                  title: 'سعر الكشف',
                  value: '$price جنيه',
                ),
                const SizedBox(height: 12),
                _AppointmentInfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'الدفع',
                  value: '$paymentMethod • $paymentText',
                  valueColor: paymentColor,
                ),
                if (clinicAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AppointmentInfoRow(
                    icon: Icons.location_on_outlined,
                    title: 'العنوان',
                    value: clinicAddress,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 15),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    label: const Text('حذف'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: const Color(0xFFD64545),
                      side: const BorderSide(color: Color(0xFFF0CACA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.event_busy_rounded, size: 19),
                      label: const Text('إلغاء الموعد'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: const Color(0xFFE8F8F6),
                        foregroundColor: _primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentInfoRow extends StatelessWidget {
  const _AppointmentInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F7F6),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF98A0AF),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? const Color(0xFF172033),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBadge extends StatelessWidget {
  const _OverviewBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.borderRadius});

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFD64545),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_rounded, size: 29, color: Colors.white),
          SizedBox(height: 4),
          Text(
            'حذف',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({
    required this.isAll,
    required this.onRefresh,
  });

  final bool isAll;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 120),
        children: [
          Center(
            child: Container(
              width: 116,
              height: 116,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 56,
                color: Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isAll ? 'لا توجد مواعيد حتى الآن' : 'لا توجد مواعيد بهذه الحالة',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'عند حجز موعد جديد سيظهر هنا مباشرة ويمكنك متابعة حالة التأكيد والدفع.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.7,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7B8494),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث المواعيد'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(170, 48),
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsLoading extends StatelessWidget {
  const _AppointmentsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => Container(
        height: 230,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8EBF0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF0F766E),
          ),
        ),
      ),
    );
  }
}
