import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';


import 'home_auto.dart';
import 'home_manual.dart';
import 'ai_screen.dart';
import 'sign_up.dart';

class ProfileScreen extends StatefulWidget {
  final bool lastHomeIsManual; // true = آخر صفحة Home كانت Manual

  const ProfileScreen({
    super.key,
    required this.lastHomeIsManual,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int bottomIndex = 2; // 0 = home, 1 = ai, 2 = profile
  final TextEditingController _tankHeightController = TextEditingController();
  double? _tankHeight;

  bool _isLoading = true;
  String? _fullName;
  String? _email;
  String? _espId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      // لو ما في مستخدم مسجّل دخول → رجعه لـ SignUp
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const SignUp()),
                (route) => false,
          );
        });
        return;
      }

      final uid = user.uid;
      String? fullName = user.displayName;
      String? email = user.email;
      String? espId;

      // نحاول نجيب البيانات من Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        fullName = (data['fullName'] as String?)?.trim() ?? fullName;
        email = (data['email'] as String?) ?? email;

        if (data['espId'] != null) {
          espId = data['espId'].toString();
        }

        if (data['tankHeight'] != null) {
          _tankHeight = (data['tankHeight'] as num).toDouble();
          _tankHeightController.text = _tankHeight!.toString();
        }
      }


      if (!mounted) return;

      setState(() {
        _fullName = fullName ?? 'Unknown user';
        _email = email ?? 'No email';
        _espId = espId; // ممكن تكون null لو لسا ما ربط الـ ESP
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load profile data';
        _isLoading = false;
      });
    }
  }

  TextEditingController tankController = TextEditingController();

// عند الضغط على زر حفظ:
  Future<void> saveTankHeight() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final value = double.tryParse(_tankHeightController.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tank height')),
      );
      return;
    }

    try {
      // 1️⃣ حفظ في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'tankHeight': value,
      }, SetOptions(merge: true));

      // 2️⃣ حفظ في Realtime Database
      await FirebaseDatabase.instance
          .ref('devices/$_espId/tankHeight')
          .set(value);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ طول الخزان بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e')),
      );
    }
  }



  Future<void> _logout() async {
    try {
      final auth = FirebaseAuth.instance;

      // تسجيل خروج من Firebase
      await auth.signOut();

      // نحاول نسوي تسجيل خروج من Google (لو كان مسجل بجوجل)
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // نتجاهل أي خطأ هنا
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignUp()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to logout, please try again')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED);
    const Color primaryColor = Color(0xFF3A6F51);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              children: [
                // الحاوية الكبيرة ذات الزوايا الدائرية
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),

                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Avatar
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFFDFF7E1),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: primaryColor,
                            child: const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // حالة تحميل / خطأ بسيطة فوق البطاقة
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Loading profile...',
                              style: TextStyle(fontSize: 13),
                            ),
                          )
                        else if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                              ),
                            ),
                          ),

                        // بطاقة البيانات
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FFFA),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full Name
                                const Text(
                                  'Full Name',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isLoading
                                      ? '...'
                                      : (_fullName ?? 'Unknown user'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                    color: Colors.grey.shade300, height: 1),
                                const SizedBox(height: 12),

                                // Email
                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isLoading
                                      ? '...'
                                      : (_email ?? 'No email'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Divider(
                                    color: Colors.grey.shade300, height: 1),
                                const SizedBox(height: 11),

                                // ESP ID
                                const Text(
                                  'ESP ID',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isLoading
                                      ? '...'
                                      : (_espId ?? 'No Esp'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Divider(color: Colors.grey.shade300, height: 1),
                                const SizedBox(height: 11),

// Tank Height
                                const Text(
                                  'Tank Height (cm)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                TextField(
                                  controller: _tankHeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Enter tank height in cm',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    onPressed: saveTankHeight,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: const Text(
                                      'Save',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // زر Logout
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: SizedBox(
                            width: 160,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _logout,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FFFA),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
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

      // ===== Bottom bar ثابت أسفل الصفحة بالكامل =====
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home
            GestureDetector(
              onTap: () {
                // يرجع لآخر صفحة Home (Auto / Manual)
                if (widget.lastHomeIsManual) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeManualScreen(),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HomeAutoScreen(),
                    ),
                  );
                }
              },
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/home_icon.png',
                  height: 30,
                ),
              ),
            ),

            // AI
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AiScreen(lastHomeIsManual: widget.lastHomeIsManual),
                  ),
                );
              },
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/ai_icon.png',
                  height: 30,
                ),
              ),
            ),

            // Profile (الصفحة الحالية)
            GestureDetector(
              onTap: () {},
              child: Opacity(
                opacity: 1.0,
                child: Image.asset(
                  'assets/images/prof_icon.png',
                  height: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
