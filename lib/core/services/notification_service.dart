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
    String? route,
  }) async {
    await _send({
      'building_id': buildingId,
      'title': title,
      'body': body,
      if (excludeUserId != null) 'exclude_user_id': excludeUserId,
      if (route != null) 'route': route,
    });
  }

  static Future<void> sendToUser({
    required String targetUserId,
    required String title,
    required String body,
    String? route,
  }) async {
    await _send({
      'target_user_id': targetUserId,
      'title': title,
      'body': body,
      if (route != null) 'route': route,
    });
  }

  static Future<void> _send(Map<String, dynamic> payload) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode(payload),
      );

    } catch (e, s) {
      debugPrint('NotificationService error: $e');
      debugPrint('NotificationService stack: $s');
    }
  }
}
