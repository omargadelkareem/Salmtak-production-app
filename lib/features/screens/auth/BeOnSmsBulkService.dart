import 'dart:convert';

import 'package:http/http.dart' as http;

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

    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(payload),
    );

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    // Debug logs
    print("========== BeOn Request ==========");
    print("URL: $url");
    print("Headers: $headers");
    print("Payload: $payload");
    print("Status: ${res.statusCode}");
    print("Response: ${res.body}");
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
  }
}

class BeOnSmsService {
  static const String _url =
      "https://v3.api.beon.chat/api/v3/messages/sms/bulk";

  final BeOnHttp _http;

  BeOnSmsService({required String token}) : _http = BeOnHttp(token: token);

  Future<SmsSendResult> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    final payload = {
      "phoneNumbers": [phoneNumber],
      "message": message,
    };

    return await _http.postJson(_url, payload);
  }
}
