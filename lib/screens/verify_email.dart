import 'package:flutter/material.dart';
import 'new_password.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _goToNewPassword() {
    final code = _codeController.text.trim();

    if (code.length != 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code must be 5 digits')));
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NewPasswordScreen(email: widget.email, code: code),
      ),
    );
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
          // ========= المحتوى الأساسي (النص + الحقول + الأزرار) =========
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

                      const Text(
                        'Enter the verification code we\nsent to your email address.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black87),
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
                          onPressed: _goToNewPassword,
                          child: const Text(
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

                      // مسافة علشان ما تتصادم النصوص مع الصور تحت
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ========= صورة البحر (SEA) ملتصقة بطرف الشاشة =========
          Positioned(
            right: 0,
            bottom: 0,
            child: Image.asset(
              'assets/images/sea.png',
              width: screenWidth * 0.75, // تمتد من اليمين وتغطي جزء كبير
              fit: BoxFit.cover,
            ),
          ),

          // ========= صورة النبتة (FLOWER1) في أسفل يسار الشاشة =========
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

//==============================================
//       TextField مع Hint يختفي عند الكتابة
//==============================================
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
      decoration: InputDecoration(
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
