import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';

import 'beon_sms_service.dart';

/// =========================================================
/// ✅ OTP Result
/// =========================================================
class OtpResult {
  final bool ok;
  final String message;

  const OtpResult(this.ok, this.message);
}

/// =========================================================
/// ✅ OTP Manager
/// تخزين OTP محليًا في Firebase Realtime Database
/// وإرساله عبر BeOn SMS
///
/// المسار:
/// otp_requests/{purpose}/{phoneKey}
///
/// purpose:
/// - register
/// - forgot
/// =========================================================
class OtpManager {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final BeOnSmsService sms;

  OtpManager({required this.sms});

  /// إزالة أي رموز غير أرقام
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// التحقق من رقم مصري
  bool looksLikeEgyptPhone(String input) {
    final p = input.trim().replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('01') && p.length == 11) return true;
    if (p.startsWith('201') && p.length == 12) return true;
    if (p.startsWith('+201') && p.length == 13) return true;
    return false;
  }

  /// تحويل الرقم إلى صيغة مناسبة للإرسال
  /// 01012345678 -> +201012345678
  String normalizeEgyptPhoneForSms(String input) {
    var p = input.trim().replaceAll(' ', '').replaceAll('-', '');

    if (p.startsWith('01') && p.length == 11) {
      return '+20${p.substring(1)}';
    }
    if (p.startsWith('201') && p.length == 12) {
      return '+$p';
    }
    if (p.startsWith('+201') && p.length == 13) {
      return p;
    }

    return p;
  }

  /// مفتاح التخزين داخل Firebase
  String _phoneKeyForStorage(String phoneSms) => _digitsOnly(phoneSms);

  /// توليد OTP
  String _genOtp({int len = 6}) {
    final r = Random.secure();
    return List.generate(len, (_) => r.nextInt(10)).join();
  }

  /// توليد Salt
  String _genSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Encode(bytes);
  }

  /// Hash OTP + Salt
  String _hash(String otp, String salt) {
    return sha256.convert(utf8.encode('$otp$salt')).toString();
  }

  /// =========================================================
  /// ✅ Send OTP
  /// =========================================================
  Future<OtpResult> sendOtp({
    required String phoneRaw,
    required String purpose,
    required String name,
    int ttlSec = 300,
  }) async {
    if (!looksLikeEgyptPhone(phoneRaw)) {
      return const OtpResult(false, 'رقم الهاتف غير صحيح');
    }

    final safeName = name.trim().isEmpty ? 'User' : name.trim();
    final phoneSms = normalizeEgyptPhoneForSms(phoneRaw);
    final phoneKey = _phoneKeyForStorage(phoneSms);

    final ref = _db.child('otp_requests').child(purpose).child(phoneKey);

    try {
      /// ✅ Rate Limit: منع إعادة الإرسال قبل 60 ثانية
      final prev = await ref.get();
      if (prev.exists && prev.value != null) {
        final data = Map<dynamic, dynamic>.from(prev.value as Map);

        final lastSend = (data['lastSendAt'] ?? 0) is int
            ? (data['lastSendAt'] as int)
            : int.tryParse('${data['lastSendAt']}') ?? 0;

        final now = DateTime.now().millisecondsSinceEpoch;

        if (lastSend > 0 && now - lastSend < 60 * 1000) {
          return const OtpResult(false, 'انتظر دقيقة قبل إعادة إرسال الكود');
        }
      }

      final otp = _genOtp();
      final salt = _genSalt();
      final hash = _hash(otp, salt);

      final now = DateTime.now().millisecondsSinceEpoch;
      final expiresAt = now + ttlSec * 1000;

      /// ✅ تخزين النسخة المشفرة فقط
      await ref.set({
        "phoneSms": phoneSms,
        "otpHash": hash,
        "salt": salt,
        "expiresAt": expiresAt,
        "attempts": 0,
        "maxAttempts": 5,
        "lastSendAt": now,
        "createdAt": ServerValue.timestamp,
      });

      final smsRes = await sms.sendSms(
        phoneNumber: phoneSms,
        message:
            "مرحباً $safeName\nرمز التحقق الخاص بك هو: $otp\nصالح لمدة ${ttlSec ~/ 60} دقائق.\nلا تشارك هذا الرمز.",
      );

      if (!smsRes.ok) {
        await ref.remove();
        return OtpResult(
          false,
          'فشل إرسال OTP: ${smsRes.message} (http=${smsRes.httpCode})',
        );
      }

      return const OtpResult(true, 'تم إرسال OTP');
    } catch (e) {
      return OtpResult(false, 'حدث خطأ أثناء إرسال OTP: $e');
    }
  }

  /// =========================================================
  /// ✅ Verify OTP
  /// =========================================================
  Future<OtpResult> verifyOtp({
    required String phoneRaw,
    required String purpose,
    required String code,
  }) async {
    if (!looksLikeEgyptPhone(phoneRaw)) {
      return const OtpResult(false, 'رقم الهاتف غير صحيح');
    }

    final phoneSms = normalizeEgyptPhoneForSms(phoneRaw);
    final phoneKey = _phoneKeyForStorage(phoneSms);
    final ref = _db.child('otp_requests').child(purpose).child(phoneKey);

    try {
      final snap = await ref.get();

      if (!snap.exists || snap.value == null) {
        return const OtpResult(false, 'لا يوجد OTP لهذا الرقم');
      }

      final data = Map<dynamic, dynamic>.from(snap.value as Map);

      final expiresAt = (data["expiresAt"] ?? 0) is int
          ? (data["expiresAt"] as int)
          : int.tryParse('${data["expiresAt"]}') ?? 0;

      final attempts = (data["attempts"] ?? 0) is int
          ? (data["attempts"] as int)
          : int.tryParse('${data["attempts"]}') ?? 0;

      final maxAttempts = (data["maxAttempts"] ?? 5) is int
          ? (data["maxAttempts"] as int)
          : int.tryParse('${data["maxAttempts"]}') ?? 5;

      final now = DateTime.now().millisecondsSinceEpoch;

      if (expiresAt > 0 && now > expiresAt) {
        await ref.remove();
        return const OtpResult(false, 'انتهت صلاحية OTP');
      }

      if (attempts >= maxAttempts) {
        await ref.remove();
        return const OtpResult(false, 'تم تجاوز عدد المحاولات');
      }

      final salt = (data["salt"] ?? "").toString();
      final otpHash = (data["otpHash"] ?? "").toString();

      /// ✅ زيادة عدد المحاولات قبل التحقق
      await ref.update({"attempts": attempts + 1});

      final enteredHash = _hash(code.trim(), salt);
      final ok = enteredHash == otpHash;

      if (!ok) {
        return const OtpResult(false, 'OTP غير صحيح');
      }

      await ref.remove();
      return const OtpResult(true, 'تم التحقق بنجاح');
    } catch (e) {
      return OtpResult(false, 'حدث خطأ أثناء التحقق من OTP: $e');
    }
  }

  /// =========================================================
  /// ✅ Optional: Resend OTP
  /// =========================================================
  Future<OtpResult> resendOtp({
    required String phoneRaw,
    required String purpose,
    required String name,
    int ttlSec = 300,
  }) async {
    return sendOtp(
      phoneRaw: phoneRaw,
      purpose: purpose,
      name: name,
      ttlSec: ttlSec,
    );
  }
}
