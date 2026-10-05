import 'dart:convert';
import 'package:http/http.dart' as http;

class BeOnSmsTemplateService {
  static const String _url =
      "https://v3.api.beon.chat/api/v3/messages/sms/template";

  final String token; // ✅ beon-token

  BeOnSmsTemplateService({required this.token});

  Future<bool> sendTemplate({
    required String name,
    required String phoneNumber,
    required String templateId,
  }) async {
    final res = await http.post(
      Uri.parse(_url),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "beon-token": token,
      },
      body: jsonEncode({
        "name": name,
        "phoneNumber": phoneNumber,
        "template_id": templateId,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["status"] == 200;
    }
    return false;
  }
}