import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ جديد

import 'enter_esp_id.dart';
import 'sign_up.dart';
import 'forgot_password.dart';
import 'home_auto.dart'; // غيّر اسم الملف/الكلاس إذا مختلف عندك

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ جديد: إعداد وحفظ FCM Token في users/{uid}.fcmToken
  Future<void> _setupFcmToken(User user) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // طلب الإذن (خاصة في أندرويد 13+)
      await messaging.requestPermission();

      final token = await messaging.getToken();
      debugPrint('🔥 FCM Token: $token');

      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error setting up FCM token: $e');
    }
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;

      // 1) تسجيل الدخول في Firebase Auth
      final credential = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User is null after sign in',
        );
      }

      // 2) نجيب وثيقة المستخدم من Firestore: users/{uid}
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // يعني المستخدم ما كمّل التسجيل / التحقق
        await auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account is not completed. Please sign up again and verify your email.',
            ),
          ),
        );
        return;
      }

      final data = doc.data()!;
      final bool isEmailVerified = data['isEmailVerified'] == true;

      if (!isEmailVerified) {
        await auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please verify your email with the code sent to you before logging in.',
            ),
          ),
        );
        return;
      }

      // ✅ بعد التأكد أن الحساب مكتمل ومتحقق → خزّن الـ FCM Token
      await _setupFcmToken(user);

      // 3) نقرأ الـ espId من وثيقة المستخدم
      final String? espId = data['espId'] as String?;

      if (!mounted) return;

      if (espId == null || espId.isEmpty) {
        // المستخدم ما ربطش جهازه → نودّيه لواجهة إدخال ESP ID
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EnterEspIdScreen()),
        );
      } else {
        // عنده ESP ID محفوظ → نودّيه مباشرة للهوم
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeAutoScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} - ${e.message}');

      String message = 'Something went wrong, please try again';

      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint('Login error (other): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error while logging in')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ================== واجهة المستخدم (تصميم) ==================
  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED); // خلفية الشاشة
    const Color cardColor = Color(0xFFF8FFFA); // الكارد
    const Color fieldBackground = Color(0xFFFEFEFE); // حقول الإدخال
    const Color hintColor = Color(0xFF688080); // لون النص داخل الحقول
    const Color buttonColor = Color(0xFF3A6F51); // لون زر Login
    const Color buttonTextColor = Color(0xFFCFDCCE); // لون نص الزر

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: buttonColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email
                    _buildTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      hintColor: hintColor,
                      fieldBackground: fieldBackground,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password
                    _buildTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      obscureText: _obscurePassword,
                      hintColor: hintColor,
                      fieldBackground: fieldBackground,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: hintColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: buttonColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
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
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: buttonTextColor,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Go to Sign up
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 14, color: hintColor),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUp()),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: buttonColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================== ويدجت حقل النص ==================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color hintColor,
    required Color fieldBackground,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: fieldBackground,
        hintText: hintText,
        hintStyle: TextStyle(color: hintColor),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3A6F51), width: 1.2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
