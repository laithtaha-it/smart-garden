import 'dart:convert'; // ✅ جديد
import 'package:flutter/material.dart';
import 'home_manual.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http; // ✅ جديد

// 🔗 غيّر هذا بالرابط الحقيقي للفنكشن اللي ترسل الإشعار
const String kNotifyModeChangeUrl = ''; // مثال

class HomeAutoScreen extends StatefulWidget {
  const HomeAutoScreen({super.key});

  @override
  State<HomeAutoScreen> createState() => _HomeAutoScreenState();
}

class _HomeAutoScreenState extends State<HomeAutoScreen> {
  int bottomIndex = 0; // 0 = home, 1 = AI, 2 = profile

  String? _espId;

  @override
  void initState() {
    super.initState();
    // أول ما ندخل صفحة الأوتوماتيك نخلي المود = auto (بدون إشعار)
    _setMode('auto');
  }

  // ===================== Helpers لـ espId / mode =====================

  Future<String?> _ensureEspId() async {
    if (_espId != null && _espId!.isNotEmpty) return _espId;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;

    final data = doc.data() as Map<String, dynamic>;
    final espId = data['espId'] as String?;
    if (!mounted) return espId;

    setState(() {
      _espId = espId;
    });
    return espId;
  }

  Future<void> _setMode(String mode) async {
    final espId = await _ensureEspId();
    if (espId == null || espId.isEmpty) return;

    final ref = FirebaseDatabase.instance.ref('devices/$espId/mode');
    await ref.set(mode);
  }

  // ✅ جديد: استدعاء API لإرسال إشعار تغيير المود
  Future<void> _notifyModeChange(String modeLabel) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uri = Uri.parse(kNotifyModeChangeUrl);
      final body = jsonEncode({
        'uid': user.uid,
        'mode': modeLabel, // مثال: "Manual" أو "Automatic"
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint(
        'notifyModeChange($modeLabel) status: ${response.statusCode}, body: ${response.body}',
      );
    } catch (e) {
      debugPrint('notifyModeChange error: $e');
    }
  }

  // ===================================================================

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED);
    const Color primaryColor = Color(0xFF3A6F51);
    const Color greyText = Color(0xFF555555);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            const Text(
              'Smart Garden',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 24),

            // ===== التابات =====
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Automatic (محدد هنا)
                Column(
                  children: [
                    const Text(
                      'Automatic',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(height: 2, width: 80, color: primaryColor),
                  ],
                ),
                const SizedBox(width: 32),

                // Manual (ينتقل لصفحة أخرى)
                GestureDetector(
                  onTap: () async {
                    // تغيير المود إلى manual قبل الانتقال + إرسال إشعار
                    await _setMode('manual');
                    await _notifyModeChange('Manual'); // ✅ هنا الإشعار

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomeManualScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Manual',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: greyText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ===== دوائر النِّسب من Firebase =====
            _buildDeviceStatsSection(),

            const SizedBox(height: 32),

            const Text(
              'System is running\nautomatically',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: greyText,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            Image.asset(
              'assets/images/grass.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// ===== جزء عرض بيانات الحساسات من Firebase =====
  Widget _buildDeviceStatsSection() {
    const Color primaryColor = Color(0xFF3A6F51);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text(
        'No logged-in user',
        style: TextStyle(color: primaryColor),
      );
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FutureBuilder<DocumentSnapshot>(
      future: docRef.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Text(
            'Cannot load user data',
            style: TextStyle(color: primaryColor),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? espId = data['espId'] as String?;

        if (espId == null || espId.isEmpty) {
          return const Text(
            'No ESP device linked.\nPlease enter ESP ID first.',
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryColor),
          );
        }

        final DatabaseReference deviceRef = FirebaseDatabase.instance.ref(
          'devices/$espId',
        );

        return StreamBuilder<DatabaseEvent>(
          stream: deviceRef.onValue,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError ||
                !snap.hasData ||
                snap.data!.snapshot.value == null) {
              return const Text(
                'Waiting for data from device...',
                style: TextStyle(color: primaryColor),
              );
            }

            final raw = snap.data!.snapshot.value as Map<dynamic, dynamic>;

            final double soilRaw = (raw['soilRaw'] ?? 0).toDouble();
            final double waterPercent = (raw['waterPercent'] ?? 0).toDouble();

            double soilPercent = 0;
            if (soilRaw <= 0) {
              soilPercent = 100;
            } else if (soilRaw >= 4095) {
              soilPercent = 0;
            } else {
              soilPercent = 100 - (soilRaw / 4095.0 * 100.0);
            }

            soilPercent = soilPercent.clamp(0, 100);
            final soilValue = soilPercent / 100.0;
            final waterValue = (waterPercent / 100.0).clamp(0.0, 1.0);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleIndicator(
                  value: soilValue,
                  color: const Color(0xFF5AB75A),
                  label: 'Soil Moisture',
                  percentageText: '${soilPercent.toStringAsFixed(0)}%',
                ),
                const SizedBox(width: 32),
                _buildCircleIndicator(
                  value: waterValue,
                  color: const Color(0xFF4CB5C8),
                  label: 'Water Level',
                  percentageText: '${waterPercent.toStringAsFixed(0)}%',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCircleIndicator({
    required double value,
    required Color color,
    required String label,
    required String percentageText,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Text(
                percentageText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A4A4A),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // home (نفس الشاشة)
          _buildBottomItem(index: 0, iconPath: 'assets/images/home_icon.png'),

          // ai
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiScreen(lastHomeIsManual: false),
                ),
              );
            },
            child: Opacity(
              opacity: 0.5,
              child: Image.asset('assets/images/ai_icon.png', height: 30),
            ),
          ),

          // profile
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(lastHomeIsManual: false),
                ),
              );
            },
            child: Opacity(
              opacity: 0.5,
              child: Image.asset('assets/images/prof_icon.png', height: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomItem({required int index, required String iconPath}) {
    final bool isSelected = bottomIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          bottomIndex = index;
        });
      },
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Image.asset(iconPath, height: 30),
      ),
    );
  }
}
