import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'home_auto.dart';
import 'home_manual.dart';
import 'profile_screen.dart';

class AiScreen extends StatefulWidget {
  final bool lastHomeIsManual;

  const AiScreen({super.key, required this.lastHomeIsManual});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  int bottomIndex = 1;

  final _picker = ImagePicker();

  File? _selectedImage;
  String? _caseId;

  bool _uploading = false;
  bool _analyzing = false;

  // نتيجة
  String? _label;
  double? _confidence; // 0..1
  String? _status; // PROCESSING / DONE / FAILED
  String? _error;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _caseSub;

  @override
  void dispose() {
    _caseSub?.cancel();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (xfile == null) return;

    setState(() {
      _selectedImage = File(xfile.path);
      _label = null;
      _confidence = null;
      _status = null;
      _error = null;
      _caseId = null;
    });
  }

  Future<void> _pickImageFromCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
    if (xfile == null) return;

    setState(() {
      _selectedImage = File(xfile.path);
      _label = null;
      _confidence = null;
      _status = null;
      _error = null;
      _caseId = null;
    });
  }

  Future<void> _uploadAndAnalyze() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMsg("لازم تسجّل دخول أولاً");
      return;
    }
    if (_selectedImage == null) {
      _showMsg("اختر صورة أولاً");
      return;
    }

    final uid = user.uid;
    final caseId = DateTime.now().millisecondsSinceEpoch.toString();
    final path = "plant_diagnosis/$uid/$caseId.jpg";

    setState(() {
      _uploading = true;
      _analyzing = true;
      _caseId = caseId;
      _status = "UPLOADING";
      _error = null;
      _label = null;
      _confidence = null;
    });

    try {
      // 1) اكتب case مبدئي في Firestore (اختياري لكنه يساعد)
      final caseRef = FirebaseFirestore.instance
          .collection("plantDiagnosis")
          .doc(uid)
          .collection("cases")
          .doc(caseId);

      await caseRef.set({
        "status": "UPLOADING",
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) ارفع الصورة إلى Storage
      final storageRef = FirebaseStorage.instance.ref().child(path);
      await storageRef.putFile(
        _selectedImage!,
        SettableMetadata(contentType: "image/jpeg"),
      );
      await caseRef.set({
        "status": "UPLOADED",
        "imagePath": path,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


      setState(() {
        _uploading = false;
        _status = "PROCESSING"; // Function راح تكتب PROCESSING/DONE
      });

      // 3) اشترك في Firestore عشان نلتقط النتيجة لما Function تخلص
      _caseSub?.cancel();
      _caseSub = caseRef.snapshots().listen((snap) {
        if (!snap.exists) return;
        final data = snap.data()!;
        final status = (data["status"] ?? "") as String;

        setState(() {
          _status = status;
          _error = data["error"] as String?;
        });

        if (status == "DONE") {
          final label = data["label"] as String?;
          final conf = data["confidence"];
          setState(() {
            _label = label;
            _confidence = (conf is num) ? conf.toDouble() : null;
            _analyzing = false;
          });
        } else if (status == "FAILED") {
          setState(() {
            _analyzing = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _uploading = false;
        _analyzing = false;
        _status = "FAILED";
        _error = e.toString();
      });
      _showMsg("صار خطأ: $e");
    }
  }

  void _showPickDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("اختيار من المعرض"),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("تصوير بالكاميرا"),
              onTap: () async {
                Navigator.pop(context);
                await _pickImageFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFECF6ED);
    const Color primaryColor = Color(0xFF3A6F51);
    const Color resultGreen = Color(0xFF2E9444);

    final confidencePercent = _confidence == null ? null : (_confidence! * 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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

                      const SizedBox(height: 20),

                      const Text(
                        'AI?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),

                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: _showPickDialog,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryColor, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: const Color(0xFFF8FFFA),
                        ),
                        icon: const Icon(Icons.camera_alt, color: primaryColor),
                        label: const Text(
                          'Upload Photo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FFFA),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: _selectedImage == null
                              ? Image.asset('assets/images/photo_icon.png', height: 90, fit: BoxFit.contain)
                              : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(_selectedImage!, height: 180, fit: BoxFit.cover),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: 220,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_uploading || _analyzing) ? null : _uploadAndAnalyze,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3CB151),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            _uploading ? "Uploading..." : (_analyzing ? "Analyzing..." : "Analyze"),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FFFA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (_status == null) ...[
                              const Text(
                                "ارفع صورة ثم اضغط Analyze",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              )
                            ] else if (_status == "PROCESSING" || _status == "UPLOADING") ...[
                              Text(
                                "Status: ${_status!}",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              const CircularProgressIndicator(strokeWidth: 3),
                            ] else if (_status == "DONE") ...[
                              Text(
                                _label ?? "Unknown",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Confidence: ${confidencePercent ?? '-'}%",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: resultGreen),
                                textAlign: TextAlign.center,
                              ),
                            ] else if (_status == "FAILED") ...[
                              const Text(
                                "فشل التحليل",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _error ?? "Unknown error",
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ]
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ✅ قلل ارتفاع العشب عشان ما يسبب Overflow
                      Image.asset(
                        'assets/images/grass.png',
                        width: double.infinity,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),


      // Bottom Navigation
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () {
                if (widget.lastHomeIsManual) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeManualScreen()));
                } else {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeAutoScreen()));
                }
              },
              child: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/images/home_icon.png', height: 30),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Opacity(
                opacity: 1.0,
                child: Image.asset('assets/images/ai_icon.png', height: 30),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(lastHomeIsManual: widget.lastHomeIsManual)),
                );
              },
              child: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/images/prof_icon.png', height: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
