import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

// شاشة "انضم إلينا"

const Color kPrimaryColor = Color(0xFF0F766E);
const Color kSecondaryColor = Color(0xFF14B8A6);
const Color kBackgroundColor = Color(0xFFF6F8FA);
const Color kTextColor = Color(0xFF0F172A);

class JoinAsDoctorScreen extends StatefulWidget {
  const JoinAsDoctorScreen({super.key});

  @override
  State<JoinAsDoctorScreen> createState() => _JoinAsDoctorScreenState();
}

class _JoinAsDoctorScreenState extends State<JoinAsDoctorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _doctorNameController = TextEditingController();

  final TextEditingController _centerController = TextEditingController();

  final TextEditingController _clinicAddressController =
      TextEditingController();

  final TextEditingController _clinicPhoneController = TextEditingController();

  final TextEditingController _doctorPhoneController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GetStorage _storage = GetStorage();

  bool _isSubmitting = false;
  String? _selectedGovernorate;

  final List<String> _governorates = const [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'البحر الأحمر',
    'البحيرة',
    'الفيوم',
    'الغربية',
    'الإسماعيلية',
    'المنوفية',
    'المنيا',
    'القليوبية',
    'الوادي الجديد',
    'السويس',
    'أسوان',
    'أسيوط',
    'بني سويف',
    'بورسعيد',
    'دمياط',
    'الشرقية',
    'جنوب سيناء',
    'كفر الشيخ',
    'مطروح',
    'الأقصر',
    'قنا',
    'شمال سيناء',
    'سوهاج',
  ];

  @override
  void dispose() {
    _doctorNameController.dispose();
    _centerController.dispose();
    _clinicAddressController.dispose();
    _clinicPhoneController.dispose();
    _doctorPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRecommendation() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    if (_selectedGovernorate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار المحافظة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final String recommendationId =
          _database.child('doctorRecommendations').push().key!;

      final String userId = (_storage.read('userId') ?? '').toString().trim();

      final String userName =
          (_storage.read('userName') ?? '').toString().trim();

      final String userPhone =
          (_storage.read('userPhone') ?? _storage.read('phone') ?? '')
              .toString()
              .trim();

      final Map<String, dynamic> recommendationData = {
        'id': recommendationId,
        'doctorName': _doctorNameController.text.trim(),
        'governorate': _selectedGovernorate,
        'center': _centerController.text.trim(),
        'clinicAddress': _clinicAddressController.text.trim(),
        'clinicPhone': _clinicPhoneController.text.trim(),
        'doctorPhone': _doctorPhoneController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'submittedBy': {
          'userId': userId,
          'userName': userName,
          'userPhone': userPhone,
        },
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      };

      await _database
          .child('doctorRecommendations')
          .child(recommendationId)
          .set(recommendationData);

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      await _showSuccessDialog();
    } catch (error) {
      debugPrint('Submit doctor recommendation error: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حدث خطأ أثناء إرسال الترشيح، حاول مرة أخرى',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _doctorNameController.clear();
    _centerController.clear();
    _clinicAddressController.clear();
    _clinicPhoneController.clear();
    _doctorPhoneController.clear();
    _notesController.clear();
    setState(() => _selectedGovernorate = null);
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 35,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        kSecondaryColor,
                        kPrimaryColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'شكرًا لترشيحك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'تم استلام بيانات الطبيب بنجاح، وسيقوم فريقنا بمراجعتها والتواصل معه للانضمام إلى التطبيق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.7,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _clearForm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'تم',
                      style: TextStyle(
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
      },
    );
  }

  String? _requiredValidator(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }

    if (value.trim().length < 2) {
      return 'يرجى إدخال $fieldName بشكل صحيح';
    }

    return null;
  }

  String? _phoneValidator(
    String? value, {
    required bool required,
  }) {
    final String phone = (value ?? '').trim();

    if (phone.isEmpty) {
      return required ? 'يرجى إدخال رقم الهاتف' : null;
    }

    final String normalizedPhone = phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    if (normalizedPhone.length < 8 || normalizedPhone.length > 15) {
      return 'يرجى إدخال رقم هاتف صحيح';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextColor,
        title: const Text(
          'رشّح طبيبًا',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const _SectionTitle(
                  title: 'بيانات الطبيب',
                  subtitle: 'أدخل المعلومات المتاحة لديك عن الطبيب.',
                  icon: Icons.person_add_alt_1_rounded,
                ),
                const SizedBox(height: 14),
                _FormCard(
                  children: [
                    _ProfessionalTextField(
                      controller: _doctorNameController,
                      label: 'اسم الطبيب',
                      hint: 'مثال: د. أحمد محمد علي',
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _requiredValidator(
                        value,
                        'اسم الطبيب',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _GovernorateDropdown(
                      value: _selectedGovernorate,
                      governorates: _governorates,
                      onChanged: (value) {
                        setState(() {
                          _selectedGovernorate = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _ProfessionalTextField(
                      controller: _centerController,
                      label: 'المركز أو المدينة',
                      hint: 'مثال: طهطا',
                      icon: Icons.location_city_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _requiredValidator(
                        value,
                        'المركز أو المدينة',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfessionalTextField(
                      controller: _clinicAddressController,
                      label: 'عنوان العيادة',
                      hint: 'الشارع، اسم المبنى، الدور أو علامة مميزة',
                      icon: Icons.location_on_outlined,
                      textInputAction: TextInputAction.next,
                      maxLines: 2,
                      validator: (value) => _requiredValidator(
                        value,
                        'عنوان العيادة',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle(
                  title: 'بيانات التواصل',
                  subtitle: 'نستخدم هذه البيانات للتواصل مع الطبيب أو العيادة.',
                  icon: Icons.call_outlined,
                ),
                const SizedBox(height: 14),
                _FormCard(
                  children: [
                    _ProfessionalTextField(
                      controller: _clinicPhoneController,
                      label: 'رقم العيادة',
                      hint: 'رقم الهاتف الأرضي أو المحمول',
                      icon: Icons.local_hospital_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+]'),
                        ),
                      ],
                      validator: (value) => _phoneValidator(
                        value,
                        required: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ProfessionalTextField(
                      controller: _doctorPhoneController,
                      label: 'رقم هاتف الطبيب',
                      hint: 'اختياري',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      isOptional: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+]'),
                        ),
                      ],
                      validator: (value) => _phoneValidator(
                        value,
                        required: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle(
                  title: 'معلومات إضافية',
                  subtitle: 'أضف أي تفاصيل تساعدنا على الوصول للطبيب.',
                  icon: Icons.notes_rounded,
                ),
                const SizedBox(height: 14),
                _FormCard(
                  children: [
                    _ProfessionalTextField(
                      controller: _notesController,
                      label: 'ملاحظات',
                      hint: 'مثل تخصص الطبيب، مواعيد العمل أو أي تفاصيل أخرى',
                      icon: Icons.edit_note_rounded,
                      textInputAction: TextInputAction.done,
                      maxLines: 4,
                      isOptional: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRecommendation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: kPrimaryColor.withOpacity(0.55),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isSubmitting
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.7,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              key: ValueKey('button'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  size: 21,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'إرسال ترشيح الطبيب',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendationHeader extends StatelessWidget {
  const _RecommendationHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            kPrimaryColor,
            kSecondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -18,
            bottom: -26,
            child: Icon(
              Icons.medical_services_rounded,
              size: 130,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.17),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                  ),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ساعدنا نوصل لطبيبك',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تعرف طبيبًا متميزًا؟ رشّحه لنا وسنتواصل معه للانضمام إلى التطبيق وتسهيل حجز المواعيد للمرضى.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  height: 1.65,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: kPrimaryColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;

  const _FormCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7ECF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ProfessionalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final bool isOptional;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _ProfessionalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.isOptional = false,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: kTextColor,
        fontSize: 14.5,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (isOptional) ...[
              const SizedBox(width: 5),
              Text(
                '(اختياري)',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: kPrimaryColor,
          size: 21,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE4EAF0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: kPrimaryColor,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

class _GovernorateDropdown extends StatelessWidget {
  final String? value;
  final List<String> governorates;
  final ValueChanged<String?> onChanged;

  const _GovernorateDropdown({
    required this.value,
    required this.governorates,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 360,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: kPrimaryColor,
      ),
      style: const TextStyle(
        color: kTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: 'المحافظة',
        prefixIcon: const Icon(
          Icons.map_outlined,
          color: kPrimaryColor,
          size: 21,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE4EAF0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: kPrimaryColor,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
      ),
      hint: Text(
        'اختر المحافظة',
        style: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
      items: governorates.map((governorate) {
        return DropdownMenuItem<String>(
          value: governorate,
          child: Text(governorate),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (selectedValue) {
        if (selectedValue == null || selectedValue.trim().isEmpty) {
          return 'يرجى اختيار المحافظة';
        }

        return null;
      },
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: kPrimaryColor.withOpacity(0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: kPrimaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'سيتم استخدام البيانات للتواصل مع الطبيب بشأن الانضمام إلى التطبيق فقط، ولن يتم عرض رقم الهاتف للمستخدمين.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12.5,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
