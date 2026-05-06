import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static const _functionUrl =
      'https://pclawaxmilduvfkwhhge.supabase.co/functions/v1/send-notification';

  static Future<void> sendToBuilding({
    required String buildingId,
    required String title,
    required String body,
    String? excludeUserId,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      final accessToken = session.accessToken;

      final payload = {
        'building_id': buildingId,
        'title': title,
        'body': body,
        if (excludeUserId != null) 'exclude_user_id': excludeUserId,
      };

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      debugPrint('NotificationService status: ${response.statusCode}');
      debugPrint('NotificationService body: ${response.body}');
      debugPrint('NotificationService payload: ${jsonEncode(payload)}');
    } catch (e, s) {
      debugPrint('NotificationService error: $e');
      debugPrint('NotificationService stack: $s');
    }
  }
}
