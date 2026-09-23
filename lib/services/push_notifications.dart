import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// 🔗 حط هنا رابط الـ HTTP Trigger لدالة sendNotificationByToken
const String kSendNotificationUrl = ''; // غيّرها برابطك

Future<void> sendModeChangeNotification(String uid, String newMode) async {
  try {
    // 1) نجيب fcmToken من users/{uid}
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) {
      print('User doc not found');
      return;
    }

    final data = doc.data()!;
    final String? token = data['fcmToken'] as String?;

    if (token == null || token.isEmpty) {
      print('User has no fcmToken');
      return;
    }

    // 2) نرسل طلب للفنكشن sendNotificationByToken
    final uri = Uri.parse(kSendNotificationUrl);

    final body = {
      'token': token,
      'title': 'Mode changed',
      'body': 'Irrigation mode changed to $newMode',
      // data اختيارية
      'data': {'mode': newMode},
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    print('sendNotification status: ${response.statusCode} ${response.body}');
  } catch (e) {
    print('Error in sendModeChangeNotification: $e');
  }
}
