// lib/pages/login_page.dart

import 'package:flutter/material.dart';
// 【核心修正】使用 hide User，避免跟我們自己的 User 模型衝突
import 'package:firebase_auth/firebase_auth.dart' hide User; 
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../services/firestore_service.dart'; 
import '../models/user_model.dart'; 
import '../models/weight_log_model.dart';
import '../main.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  
  final TextEditingController _height = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _fat = TextEditingController();
  final TextEditingController _bmiController = TextEditingController();
  final TextEditingController _bmrController = TextEditingController();
  final List<bool> _genderSelection = [true, false];
  
  bool isLogin = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _height.dispose();
    _weight.dispose();
    _age.dispose();
    _fat.dispose();
    _bmiController.dispose();
    _bmrController.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() => isLogin = !isLogin);

  void _updateBMI() {
    final h = double.tryParse(_height.text);
    final w = double.tryParse(_weight.text);
    if (h != null && w != null && h > 0) {
      final bmi = w / ((h / 100) * (h / 100));
      _bmiController.text = bmi.toStringAsFixed(2);
    } else {
      _bmiController.text = '';
    }
  }

  void _updateBMR() {
    final h = double.tryParse(_height.text);
    final w = double.tryParse(_weight.text);
    final a = int.tryParse(_age.text);
    final isMale = _genderSelection[0];

    if (h != null && w != null && a != null && h > 0 && w > 0 && a > 0) {
      double bmr = 0;
      if (isMale) {
        bmr = (10 * w) + (6.25 * h) - (5 * a) + 5;
      } else {
        bmr = (10 * w) + (6.25 * h) - (5 * a) - 161;
      }
      _bmrController.text = bmr.toStringAsFixed(2);
    } else {
      _bmrController.text = '';
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      // --- 登入邏輯 ---
      if (isLogin) {
        await AuthService.instance.signIn(email, password);
        
        // 檢查本地是否有資料
        var localUser = await DatabaseHelper.instance.getUserByAccount(email);
        
        if (localUser == null) {
          // 嘗試從雲端拉取
          final cloudData = await FirestoreService.instance.getUserData();
          
          if (cloudData != null) {
            // 雲端有資料 -> 還原到本地 SQLite
            final restoredUser = User(
              account: email,
              password: 'firebase_user',
              height: cloudData['height'] ?? '170',
              weight: cloudData['weight'] ?? '60',
              age: cloudData['age'] ?? '30',
              bmi: cloudData['bmi'] ?? '20',
              fat: cloudData['fat'],
              gender: cloudData['gender'],
              bmr: cloudData['bmr'],
              goalWeight: cloudData['goalWeight'],
              nickname: cloudData['nickname'],
              hometown: cloudData['hometown'],
            );
            await DatabaseHelper.instance.insertUser(restoredUser.toMap());
          } else {
            // 雲端也沒資料 -> 建立預設使用者
            await DatabaseHelper.instance.insertUser({
              'account': email,
              'password': 'firebase_user',
              'height': '170', 'weight': '60', 'age': '30', 'bmi': '20', 
              'gender': 'male', 'bmr': '1500',
              'nickname': email.split('@')[0], 
            });
          }
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainAppShell(account: email)),
        );

      } 
      // --- 註冊邏輯 ---
      else {
        final h = double.tryParse(_height.text);
        final w = double.tryParse(_weight.text);
        final a = int.tryParse(_age.text);
        if (h == null || w == null || a == null) {
          throw Exception("請填寫完整的生理數據");
        }

        await AuthService.instance.signUp(email, password);

        final gender = _genderSelection[0] ? 'male' : 'female';
        String bmi = (w / ((h / 100) * (h / 100))).toStringAsFixed(2);
        double bmrValue = (gender == 'male') 
            ? (10 * w) + (6.25 * h) - (5 * a) + 5
            : (10 * w) + (6.25 * h) - (5 * a) - 161;
        String bmr = bmrValue.toStringAsFixed(2);

        // 1. 寫入本地 SQLite
        await DatabaseHelper.instance.insertUser({
          'account': email,
          'password': 'firebase_user',
          'height': _height.text,
          'weight': _weight.text,
          'age': _age.text,
          'bmi': bmi,
          'fat': _fat.text,
          'gender': gender,
          'bmr': bmr,
        });

        // 2. 註冊時立刻備份到雲端
        await FirestoreService.instance.syncUserData(
          height: _height.text,
          weight: _weight.text,
          age: _age.text,
          bmi: bmi,
          fat: _fat.text,
          gender: gender,
          bmr: bmr,
          nickname: email.split('@')[0], 
        );

        // 3. 自動記錄初始體重
        final firstWeightLog = WeightLog(
          weight: w, // 這裡已經確認 w 不為 null
          createdAt: DateTime.now(),
          account: email,
        );
        await DatabaseHelper.instance.insertWeightLog(firstWeightLog);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainAppShell(account: email)),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = '發生錯誤';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Email 或密碼錯誤';
      } else if (e.code == 'email-already-in-use') {
        message = '此 Email 已經被註冊過了';
      } else if (e.code == 'weak-password') {
        message = '密碼強度不足';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  const Icon(Icons.fitness_center, size: 80, color: Color(0xFF0A84FF)),
                  const SizedBox(height: 20),
                  Text(isLogin ? '歡迎回來！' : '建立您的帳戶', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(isLogin ? '登入以繼續您的訓練' : '填寫資料以開始個人化體驗', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  const SizedBox(height: 40),
                  
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', hintText: 'name@example.com', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? '請輸入 Email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: '密碼',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                    ),
                    validator: (v) => v!.isEmpty ? '請輸入密碼' : null,
                  ),
                  
                  if (!isLogin) ...[
                    const SizedBox(height: 24),
                    ToggleButtons(
                      isSelected: _genderSelection,
                      onPressed: (int index) { setState(() { for (int i = 0; i < _genderSelection.length; i++) { _genderSelection[i] = i == index; } _updateBMR(); }); },
                      borderRadius: BorderRadius.circular(8.0),
                      constraints: BoxConstraints.expand(width: (MediaQuery.of(context).size.width - 52) / 2, height: 40),
                      fillColor: _genderSelection[1] ? Colors.red.shade400 : Colors.blue.shade400,
                      selectedColor: Colors.white,
                      children: const [Text('男性'), Text('女性')],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(controller: _height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高 (cm)'), validator: (v) => v!.isEmpty ? '請輸入身高' : null, onChanged: (_) { _updateBMI(); _updateBMR(); },),
                    const SizedBox(height: 16),
                    TextFormField(controller: _weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '體重 (kg)'), validator: (v) => v!.isEmpty ? '請輸入體重' : null, onChanged: (_) { _updateBMI(); _updateBMR(); },),
                    const SizedBox(height: 16),
                    TextFormField(controller: _age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '年齡'), validator: (v) => v!.isEmpty ? '請輸入年齡' : null, onChanged: (_) => _updateBMR(),),
                    const SizedBox(height: 16),
                    TextFormField(readOnly: true, controller: _bmiController, decoration: const InputDecoration(labelText: 'BMI (自動計算)')),
                    const SizedBox(height: 16),
                    TextFormField(readOnly: true, controller: _bmrController, decoration: const InputDecoration(labelText: 'BMR (自動計算)')),
                    const SizedBox(height: 16),
                    TextFormField(controller: _fat, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '體脂率 (%) (選填)')),
                  ],
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isLogin ? '登入' : '註冊'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLogin ? '還沒有帳號？' : '已經有帳號？', style: TextStyle(color: Colors.grey.shade600)),
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Text(isLogin ? ' 馬上註冊' : ' 前往登入', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A84FF))),
                      ),
                    ],
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