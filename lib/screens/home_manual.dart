import 'dart:convert'; // ✅ جديد
import 'package:flutter/material.dart';
import 'home_auto.dart';
import 'ai_screen.dart';
import 'profile_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http; // ✅ جديد

const String kNotifyModeChangeUrl = '';

class HomeManualScreen extends StatefulWidget {
  const HomeManualScreen({super.key});

  @override
  State<HomeManualScreen> createState() => _HomeManualScreenState();
}

class _HomeManualScreenState extends State<HomeManualScreen> {
  int bottomIndex = 0;
  bool isPumpOn = false; // حالة المضخة (UI)
  bool _isSendingCommand = false;
  String? _espId; // نخزن espId هنا

  @override
  void initState() {
    super.initState();
    // أول ما ندخل صفحة المانوال نخلي المود = manual (بدون إشعار)
    _setMode('manual');
  }

  // ===================== Helpers لـ espId / mode / pumpOn =====================

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
    await ref.set(mode); // هذا اللي يشغل Cloud Function أو يخزن المود
  }

  Future<void> _setPumpOn(bool on) async {
    final espId = await _ensureEspId();
    if (espId == null || espId.isEmpty) return;

    final ref = FirebaseDatabase.instance.ref('devices/$espId/pumpOn');
    await ref.set(on);
  }

  Future<void> _togglePump() async {
    if (_isSendingCommand) return;

    setState(() {
      _isSendingCommand = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No logged-in user')));
        return;
      }

      // نجيب espId من Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User data not found')));
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final String? espId = data['espId'] as String?;

      if (espId == null || espId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ESP device linked to this account')),
        );
        return;
      }

      final newState = !isPumpOn;

      final ref = FirebaseDatabase.instance.ref('devices/$espId/remotePumpOn');

      await ref.set(newState);

      setState(() {
        isPumpOn = newState;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending command: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCommand = false;
        });
      }
    }
  }

  // ✅ جديد: استدعاء API للإشعار
  Future<void> _notifyModeChange(String modeLabel) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final uri = Uri.parse(kNotifyModeChangeUrl);
      final body = jsonEncode({
        'uid': user.uid,
        'mode': modeLabel, // "Automatic" أو "Manual"
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

  // ============================================================================

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
                // Automatic: يرجع لصفحة الأوتوماتيك
                GestureDetector(
                  onTap: () async {
                    // قبل ما نروح للأوتو نحدث المود إلى auto + إشعار
                    await _setMode('auto');
                    await _notifyModeChange('Automatic'); // ✅ هنا الإشعار

                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeAutoScreen()),
                    );
                  },
                  child: const Text(
                    'Automatic',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: greyText,
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // Manual: محدد في هذه الصفحة
                Column(
                  children: [
                    const Text(
                      'Manual',
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
              ],
            ),

            const SizedBox(height: 30),

            // ===== دوائر النِّسب من Firebase =====
            _buildDeviceStatsSection(),

            const SizedBox(height: 24),

            // ===== كرت المضخة =====
            _buildPumpCard(),

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
                  label: 'WaterLevel',
                  percentageText: '${waterPercent.toStringAsFixed(0)}%',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPumpCard() {
    const Color primaryColor = Color(0xFF3A6F51);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset('assets/images/pump_tap.png', height: 120),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 50),
                  child: Text(
                    'Pump',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: GestureDetector(
                    onTap: _isSendingCommand ? null : _togglePump,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isPumpOn
                            ? primaryColor
                            : const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPumpOn ? primaryColor : Colors.grey.shade400,
                        ),
                      ),
                      child: Text(
                        isPumpOn ? "ON" : "OFF",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPumpOn ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          _buildBottomItem(index: 0, iconPath: 'assets/images/home_icon.png'),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiScreen(lastHomeIsManual: true),
                ),
              );
            },
            child: Opacity(
              opacity: 0.5,
              child: Image.asset('assets/images/ai_icon.png', height: 30),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(lastHomeIsManual: true),
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
