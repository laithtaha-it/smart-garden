import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'enter_esp_id.dart';

/// 🔗 حط هنا رابط الـ HTTP Trigger لدالة confirmSignUp
const String kConfirmSignUpUrl = ''; // <-- غيّر هذا بالرابط من Firebase

class VerifyEmailSignUpScreen extends StatefulWidget {
  final String email;
  final String password;

  const VerifyEmailSignUpScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<VerifyEmailSignUpScreen> createState() =>
      _VerifyEmailSignUpScreenState();
}

class _VerifyEmailSignUpScreenState extends State<VerifyEmailSignUpScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final enteredCode = _codeController.text.trim();

    if (enteredCode.length != 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code must be 5 digits')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(kConfirmSignUpUrl);

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': enteredCode}),
      );

      debugPrint(
        'confirmSignUp status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        // ✅ الكود صحيح وتم إنشاء المستخدم في Auth و Firestore داخل Cloud Function

        // نحاول تسجيل الدخول بالحساب الجديد
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );
        } catch (e) {
          debugPrint('Sign in after confirmSignUp failed: $e');
        }

        if (!mounted) return;

        // ننتقل لصفحة إدخال الـ ESP ID
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnterEspIdScreen()),
        );
      } else {
        String message =
            'Failed to verify code (status ${response.statusCode})';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['error'] is String) {
            message = decoded['error'];
          }
        } catch (_) {}

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint('Error calling confirmSignUp: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error verifying code')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED);
    const Color primaryColor = Color(0xFF3A6F51);
    const Color buttonTextColor = Color(0xFFCFDCCE);
    const Color hintTextColor = Color(0xFF688080);

    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'VERIFY YOUR\nEMAIL ADDRESS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter the 5-digit code sent to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _CodeTextField(
                        controller: _codeController,
                        hint: 'Enter code',
                        hintColor: hintTextColor,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _verifyCode,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'VERIFY',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: buttonTextColor,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 150,
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'BACK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // صورة البحر
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/sea.png',
              width: screenWidth * 0.75,
              fit: BoxFit.cover,
            ),
          ),

          // صورة النبتة
          Positioned(
            left: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/flower1.png',
              height: 140,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// TextField مع Hint يختفي
class _CodeTextField extends StatefulWidget {
  final String hint;
  final Color hintColor;
  final TextEditingController controller;

  const _CodeTextField({
    required this.hint,
    required this.hintColor,
    required this.controller,
    super.key,
  });

  @override
  State<_CodeTextField> createState() => _CodeTextFieldState();
}

class _CodeTextFieldState extends State<_CodeTextField> {
  late final FocusNode _focusNode;

  bool get _showHint => !_focusNode.hasFocus && widget.controller.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.number,
      maxLength: 5,
      decoration: InputDecoration(
        counterText: '',
        hintText: _showHint ? widget.hint : null,
        hintStyle: TextStyle(color: widget.hintColor),
        filled: true,
        fillColor: const Color(0xFFFEFEFE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A6F51)),
        ),
      ),
    );
  }
}
