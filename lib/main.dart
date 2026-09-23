import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// إشعارات
import 'package:firebase_messaging/firebase_messaging.dart';
// عشان نعرف المستخدم الحالي ونحدّث بياناته
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/sign_up.dart';

/// هندلر للرسائل في الخلفية (مطلوب من FCM)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // debugPrint('Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // تسجيل هندلر الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // إعداد صلاحيات الإشعارات + حفظ/تحديث الـ FCM token
  await _setupFirebaseMessaging();

  runApp(const MyApp());
}

/// طلب صلاحية الإشعارات + حفظ الـ token في Firestore في حقل fcmToken
Future<void> _setupFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  // طلب صلاحيات الإشعارات من المستخدم
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // جلب التوكن لأول مرة
  final token = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;

  if (user != null && token != null) {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });
    debugPrint('🔥 FCM token saved: $token');
  }

  // ❗️هنا التعديل المهم:
  // بدل FirebaseMessaging.onTokenRefresh
  messaging.onTokenRefresh.listen((newToken) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({'fcmToken': newToken});
      debugPrint('🔥 FCM token refreshed: $newToken');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Graduation Project',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SignUp(),
    );
  }
}
