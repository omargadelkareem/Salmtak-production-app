import 'dart:convert';

import 'package:http/http.dart' as http;

/// =========================================================
/// ✅ SMS Result Model
/// =========================================================
class SmsSendResult {
  final bool ok;
  final int httpCode;
  final String message;
  final Map<String, dynamic>? body;

  const SmsSendResult({
    required this.ok,
    required this.httpCode,
    required this.message,
    this.body,
  });
}

/// =========================================================
/// ✅ BeOn HTTP Helper
/// =========================================================
class BeOnHttp {
  final String token;

  const BeOnHttp({required this.token});

  Future<SmsSendResult> postJson(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "beon-token": token,
    };

    print("========== BeOn Request ==========");
    print("URL: $url");
    print("Headers: $headers");
    print("Payload: $payload");

    try {
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      );

      print("Status Code: ${res.statusCode}");
      print("Raw Response: ${res.body}");

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        print("JSON parse error: $e");
      }

      print("Parsed Response: $data");
      print("=================================");

      final msg =
          (data?["message"] ?? data?["error"] ?? data?["errors"] ?? res.body)
              .toString();

      final ok = res.statusCode == 200 &&
          (data?["status"] == 200 || data?["success"] == true);

      return SmsSendResult(
        ok: ok,
        httpCode: res.statusCode,
        message: msg,
        body: data,
      );
    } catch (e) {
      print("HTTP Exception: $e");
      print("=================================");

      return SmsSendResult(
        ok: false,
        httpCode: 0,
        message: e.toString(),
        body: null,
      );
    }
  }
}

/// =========================================================
/// ✅ BeOn SMS Service
/// الصحيح هنا bulk endpoint
/// =========================================================
class BeOnSmsService {
  static const String _url =
      "https://v3.api.beon.chat/api/v3/messages/sms/bulk";

  final BeOnHttp _http;

  BeOnSmsService({required String token}) : _http = BeOnHttp(token: token);

  Future<SmsSendResult> sendSms({
    required String phoneNumber, // مثال: +201234567890
    required String message,
  }) async {
    final payload = {
      "phoneNumbers": [phoneNumber],
      "message": message,
    };

    print("========== BeOn SMS DEBUG ==========");
    print("URL: $_url");
    print("Phone: $phoneNumber");
    print("Message: $message");
    print("Payload: $payload");

    final result = await _http.postJson(_url, payload);

    print("HTTP Code: ${result.httpCode}");
    print("Response Message: ${result.message}");
    print("Response Body: ${result.body}");
    print("====================================");

    return result;
  }
}
