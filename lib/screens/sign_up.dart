import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'login.dart';
import 'verify_email_signup.dart';
import 'enter_esp_id.dart'; // لو حاب تغيّر الصفحة عدّل هنا

const String kRequestSignUpCodeUrl = '';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ==============================
  // 1) Sign Up العادي (إيميل + كود)
  // ==============================
  Future<void> _requestCode() async {
    // 1) التحقق من صحة الحقول
    if (!_formKey.currentState!.validate()) return;

    // 2) التأكد من تطابق كلمة المرور مع التأكيد
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();

      // =============== أولا: فحص Firestore ===============
      final firestore = FirebaseFirestore.instance;
      final existingUserQuery = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUserQuery.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This email already exists, please login.'),
          ),
        );
        return;
      }

      // =============== ثانيا: فحص Firebase Auth (احتياط) ===============
      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
          email,
        );

        if (methods.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This email already exists, please login.'),
            ),
          );
          return;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'fetchSignInMethodsForEmail error: ${e.code} - ${e.message}',
        );
        if (e.code == 'invalid-email') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email address')),
          );
          return;
        }
      }

      // =============== ثالثا: استدعاء Cloud Function ===============
      final uri = Uri.parse(kRequestSignUpCodeUrl);

      final body = {
        'email': email,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'password': _passwordController.text.trim(),
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      debugPrint(
        'requestSignUpCode status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification code sent to your email. Please check it.',
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailSignUpScreen(
              email: email,
              password: _passwordController.text.trim(),
            ),
          ),
        );
      } else {
        String message =
            'Failed to send verification code (status ${response.statusCode})';

        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['error'] is String) {
            message = decoded['error'];
          }
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      debugPrint('Error calling requestSignUpCode: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error while sending verification code')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ==============================
  // 2) Sign Up باستخدام Google
  // ==============================
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email']);

      // فتح نافذة اختيار الحساب
      final googleUser = await googleSignIn.signIn();

      // المستخدم رجع للخلف أو لغى
      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in cancelled')),
        );
        return;
      }

      final email = googleUser.email;

      // أولاً: نشوف هل الإيميل مسجَّل من قبل عندنا
      final auth = FirebaseAuth.instance;
      final methods = await auth.fetchSignInMethodsForEmail(email);

      if (methods.isNotEmpty) {
        // عنده حساب قديم → نرجعه لصفحة Login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This email already exists, please login from Login page.',
            ),
          ),
        );

        await googleSignIn.signOut();
        await auth.signOut();

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // المستخدم جديد → نكمل Google Sign-In
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await auth.signInWithCredential(credential);
      final user = userCred.user;

      if (user == null || user.email == null) {
        throw Exception('Google sign-in failed (user or email is null)');
      }

      // نطلب من المستخدم كلمة سر عشان نربط له Email/Password مع نفس الإيميل
      final newPassword = await _askForPassword();

      if (newPassword == null) {
        // المستخدم لغى عملية إدخال الباسورد
        await auth.signOut();
        await googleSignIn.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password setup cancelled')),
        );
        return;
      }

      // ربط مزوّد Email/Password مع نفس الحساب
      final emailPassCredential = EmailAuthProvider.credential(
        email: user.email!,
        password: newPassword,
      );

      await user.linkWithCredential(emailPassCredential);

      // إنشاء/تحديث document في users
      final firestore = FirebaseFirestore.instance;
      final usersRef = firestore.collection('users');

      final parts = (user.displayName ?? '').trim().split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      await usersRef.doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'fullName': user.displayName ?? '',
        'email': user.email!,
        'createdAt': FieldValue.serverTimestamp(),
        'espId': null,
        'isEmailVerified': true,
        'authProvider': 'google+password',
      });

      if (!mounted) return;

      // بعد ما يضبط كل شيء، دخله التطبيق (مثال: EnterEspIdScreen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EnterEspIdScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Google Sign-In Firebase error: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Google Sign-In error')),
      );
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Dialog يطلب من المستخدم كلمة سر + تأكيدها
  Future<String?> _askForPassword() async {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Set Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, null);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    final p = passController.text.trim();
                    final c = confirmController.text.trim();

                    if (p.length < 6) {
                      setState(() {
                        errorText = 'Password must be at least 6 characters';
                      });
                      return;
                    }
                    if (p != c) {
                      setState(() {
                        errorText = 'Passwords do not match';
                      });
                      return;
                    }

                    Navigator.pop(ctx, p);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==============================
  // واجهة المستخدم (التصميم)
  // ==============================
  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED); // خلفية الشاشة
    const Color cardColor = Color(0xFFF8FFFA); // المربع الكبير
    const Color fieldBackground = Color(0xFFFEFEFE); // خلفية TextField
    const Color hintColor = Color(0xFF688080); // لون النص داخل الحقول
    const Color buttonColor = Color(0xFF3A6F51); // زر Sign up
    const Color buttonTextColor = Color(0xFFCFDCCE); // لون نص Sign up

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
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: buttonColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // First Name
                    _buildTextField(
                      controller: _firstNameController,
                      hintText: 'First Name',
                      hintColor: hintColor,
                      fieldBackground: fieldBackground,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Last Name
                    _buildTextField(
                      controller: _lastNameController,
                      hintText: 'Last Name',
                      hintColor: hintColor,
                      fieldBackground: fieldBackground,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

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
                      obscureText: true,
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
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Confirm Password',
                      obscureText: true,
                      hintColor: hintColor,
                      fieldBackground: fieldBackground,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sign up button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _requestCode,
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
                                'Sign up',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: buttonTextColor,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login text
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: buttonColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Google sign in button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _signUpWithGoogle,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF3A6F51),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: fieldBackground,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign up with Google',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF3A6F51),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color hintColor,
    required Color fieldBackground,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
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
      ),
    );
  }
}
