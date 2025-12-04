import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http; // Removed
import 'dart:ui'; // For ImageFilter
import 'main_page.dart';
import 'register_page.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Animation controller for fade-in effect
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim(); // 這裡其實是 email，因為 Firebase Auth 用 email
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = '請輸入電子郵件和密碼。';
        _isLoading = false;
      });
      return;
    }

    try {
      // 使用 AuthService 進行 Firebase 登入
      await AuthService().login(username, password);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainPage(username: username), // 傳遞 email 當作 username
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = '登入失敗：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String labelText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.white70, size: 20),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
      ),
      fillColor: Colors.white.withValues(alpha: 0.1),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Black Background
          Container(color: Colors.black),

          // 2. Center Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo or Icon
                    const Icon(
                      Icons.fitness_center_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '歡迎回來',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '登入以繼續您的旅程',
                      style: TextStyle(fontSize: 16, color: Colors.white60),
                    ),
                    const SizedBox(height: 40),

                    // 3. Glassmorphism Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          constraints: const BoxConstraints(maxWidth: 400),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.05),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  '使用者名稱',
                                  Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration(
                                  '密碼',
                                  Icons.lock_outline,
                                ),
                              ),
                              const SizedBox(height: 30),

                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.blueAccent,
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4facfe),
                                            Color(0xFF00f2fe),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF4facfe,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          '登入',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: "還沒有帳號？ ",
                          style: TextStyle(color: Colors.white60, fontSize: 15),
                          children: [
                            TextSpan(
                              text: '註冊',
                              style: TextStyle(
                                color: Color(0xFF4facfe),
                                fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
