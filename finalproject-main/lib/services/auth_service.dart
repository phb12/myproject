// lib/services/auth_service.dart

// 【修改】將 firebase_auth 命名為 fbAuth，避免與我們自己的 User 模型衝突
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final fbAuth.FirebaseAuth _auth = fbAuth.FirebaseAuth.instance;

  // 【修改】使用 fbAuth.User 來明確指出這是 Firebase 的 User
  fbAuth.User? get currentUser => _auth.currentUser;

  // 註冊
  Future<fbAuth.User?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on fbAuth.FirebaseAuthException catch (e) {
      debugPrint('註冊失敗: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('註冊發生未知錯誤: $e');
      rethrow;
    }
  }

  // 登入
  Future<fbAuth.User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on fbAuth.FirebaseAuthException catch (e) {
      debugPrint('登入失敗: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('登入發生未知錯誤: $e');
      rethrow;
    }
  }

  // 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }
}