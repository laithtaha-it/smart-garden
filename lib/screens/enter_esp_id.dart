import 'package:flutter/material.dart';
import 'home_auto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class EnterEspIdScreen extends StatefulWidget {
  const EnterEspIdScreen({super.key});

  @override
  State<EnterEspIdScreen> createState() => _EnterEspIdScreenState();
}

class _EnterEspIdScreenState extends State<EnterEspIdScreen> {
  final TextEditingController _espIdController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _espIdController.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    final espId = _espIdController.text.trim();

    if (espId.isEmpty) {
      setState(() {
        _errorText = 'Please enter your ESP ID';
      });
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _errorText = null;
      });

      // 1) التأكد أن فيه مستخدم مسجّل دخول
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorText = 'No logged-in user found.\nPlease login again.';
        });
        return;
      }

      // 2) التأكد أن الـ ESP ID موجود فعلاً في Realtime Database
      final DatabaseReference deviceRef =
      FirebaseDatabase.instance.ref('devices/$espId');

      final DataSnapshot snap = await deviceRef.get();

      if (!snap.exists || snap.value == null) {
        setState(() {
          _errorText =
          'This ESP ID is not active or not found.\nMake sure the device is online.';
        });
        return;
      }

      // 3) التأكد أن هذا الـ ESP ID غير مستخدم من حساب آخر
      final QuerySnapshot existingUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('espId', isEqualTo: espId)
          .get();

      bool usedByAnotherUser = false;

      for (final doc in existingUsers.docs) {
        if (doc.id != user.uid) {
          usedByAnotherUser = true;
          break;
        }
      }

      if (usedByAnotherUser) {
        setState(() {
          _errorText =
          'This ESP ID is already linked to another account.\nYou cannot use it.';
        });
        return;
      }

      // 4) لو الأمور تمام → نحفظ الـ ESP ID في وثيقة المستخدم
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'espId': espId,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // 5) بعد الحفظ → الذهاب إلى واجهة HomeAuto (أو Dashboard)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeAutoScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _errorText = 'Error while saving ESP ID:\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED);
    const Color primaryColor = Color(0xFF3A6F51);
    const Color hintTextColor = Color(0xFF688080);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  /// عنوان الصفحة
                  const Text(
                    "Enter your ESP ID",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Scan the QR code or enter your\nESP ID manually.",
                    style: TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  /// صندوق رمز QR (بدون حدود خارجية)
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FFFA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      "assets/images/code_logo.png",
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// حقل إدخال ESP ID
                  TextField(
                    controller: _espIdController,
                    decoration: InputDecoration(
                      hintText: "Enter ESP ID",
                      hintStyle: const TextStyle(
                        color: hintTextColor,
                      ),
                      errorText: _errorText,
                      filled: true,
                      fillColor: const Color(0xFFFEFEFE),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// زر Continue
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onContinuePressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFCFDCCE),
                          ),
                        ),
                      )
                          : const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCFDCCE),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// زر BACK
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: primaryColor,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 45, vertical: 12),
                    ),
                    child: const Text(
                      "BACK",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
