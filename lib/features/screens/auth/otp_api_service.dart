import 'dart:convert';

import 'package:http/http.dart' as http;

/// BeOn Chat OTP API (v3)
class OtpApiService {
  static const String _base = "https://v3.api.beon.chat/api/v3/messages";
  static const String BEON_TOKEN =
      "6O4USvbkJ8jyHL3qUjBpLXpLezbMnna2RUrJZxYchDMpCaxTLVvU2egqBfaj"; // ✅ Bearer token

  /// لو BeOn عنده sender/brand/templateId ضيفه هنا
  static const String? senderId = null; // مثال: "SULMTAK"
  static const String? otpTemplateId = null; // مثال: "otp_template_123"

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $BEON_TOKEN",
      };

  /// ✅ Send OTP
  /// ملاحظة: لو الـ payload عندك مختلف عدّل body هنا فقط.
  Future<OtpSendResult> sendOtp({
    required String phoneE164,
    String channel = "sms", // sms | whatsapp (لو متاح)
    int ttlSeconds = 300,
    int length = 6,
  }) async {
    final uri = Uri.parse("$_base/otp");

    final body = {
      // ✅ أشهر naming
      "to": phoneE164,
      "channel": channel,
      "ttl": ttlSeconds,
      "length": length,

      // اختياري
      if (senderId != null) "sender": senderId,
      if (otpTemplateId != null) "templateId": otpTemplateId,

      // ✅ بعض الخدمات تحتاج mode/action
      // "action": "send",
    };

    final res = await http.post(uri, headers: _headers, body: jsonEncode(body));
    final json = _tryJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // ✅ حاول نقرأ requestId/referenceId
      final requestId =
          (json["requestId"] ?? json["referenceId"] ?? json["id"] ?? "")
              .toString();
      return OtpSendResult.success(requestId: requestId, raw: json);
    }

    return OtpSendResult.fail(
      message: _extractError(res, json),
      raw: json,
    );
  }

  /// ✅ Verify OTP
  /// بعض مزودي OTP بيستخدموا نفس endpoint أو endpoint مختلف.
  /// لو BeOn عندك endpoint مختلف (مثال: /otp/verify) عدّل uri فقط.
  Future<OtpVerifyResult> verifyOtp({
    required String phoneE164,
    required String code,
    String? requestId, // لو send رجّع requestId استخدمه
  }) async {
    // جرّب verify على endpoint شائع:
    // - بعضهم: POST /otp/verify
    // - بعضهم: POST /otp (action=verify)
    // هنا اخترت /otp (مرن) وبعت action=verify
    final uri = Uri.parse("$_base/otp");

    final body = {
      "to": phoneE164,
      "code": code,
      if (requestId != null && requestId.trim().isNotEmpty)
        "requestId": requestId,

      // ✅ مهم: action verify
      "action": "verify",
    };

    final res = await http.post(uri, headers: _headers, body: jsonEncode(body));
    final json = _tryJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // ✅ success flags
      final ok = (json["verified"] == true) ||
          (json["success"] == true) ||
          (json["status"]?.toString().toLowerCase() == "verified");

      return ok
          ? OtpVerifyResult.success(raw: json)
          : OtpVerifyResult.fail(
              message: "OTP not verified",
              raw: json,
            );
    }

    return OtpVerifyResult.fail(
      message: _extractError(res, json),
      raw: json,
    );
  }

  Map<String, dynamic> _tryJson(String s) {
    try {
      final v = jsonDecode(s);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return {"raw": s};
  }

  String _extractError(http.Response res, Map<String, dynamic> json) {
    final msg = (json["message"] ??
            json["error"] ??
            json["errors"] ??
            json["detail"] ??
            "")
        .toString()
        .trim();
    if (msg.isNotEmpty) return msg;
    return "HTTP ${res.statusCode}";
  }
}

class OtpSendResult {
  final bool ok;
  final String requestId;
  final String message;
  final Map<String, dynamic> raw;

  OtpSendResult._(this.ok, this.requestId, this.message, this.raw);

  factory OtpSendResult.success(
      {required String requestId, required Map<String, dynamic> raw}) {
    return OtpSendResult._(true, requestId, "", raw);
  }

  factory OtpSendResult.fail(
      {required String message, required Map<String, dynamic> raw}) {
    return OtpSendResult._(false, "", message, raw);
  }
}

class OtpVerifyResult {
  final bool ok;
  final String message;
  final Map<String, dynamic> raw;

  OtpVerifyResult._(this.ok, this.message, this.raw);

  factory OtpVerifyResult.success({required Map<String, dynamic> raw}) {
    return OtpVerifyResult._(true, "", raw);
  }

  factory OtpVerifyResult.fail(
      {required String message, required Map<String, dynamic> raw}) {
    return OtpVerifyResult._(false, message, raw);
  }
}
