// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import '../models/workout_log_model.dart'; 
import '../models/weight_log_model.dart'; 
import '../models/user_model.dart'; // 【新增】 

class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fbAuth.FirebaseAuth _auth = fbAuth.FirebaseAuth.instance;

  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }

  // 【修改】擴充此方法，支援所有個人資料欄位
  Future<void> syncUserData({
    String? nickname, 
    String? hometown,
    String? height,
    String? weight,
    String? age,
    String? bmi,
    String? fat,
    String? gender,
    String? bmr,

    String? goalWeight,
    String? photoUrl, // 【新增】
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 建立要更新的 Map，只放入非空值
    final Map<String, dynamic> data = {
      'last_active': FieldValue.serverTimestamp(),
    };
    
    if (nickname != null) data['nickname'] = nickname;
    if (hometown != null) data['hometown'] = hometown;
    if (height != null) data['height'] = height;
    if (weight != null) data['weight'] = weight;
    if (age != null) data['age'] = age;
    if (bmi != null) data['bmi'] = bmi;
    if (fat != null) data['fat'] = fat;
    if (gender != null) data['gender'] = gender;
    if (bmr != null) data['bmr'] = bmr;
    if (goalWeight != null) data['goalWeight'] = goalWeight;
    if (photoUrl != null) data['photoUrl'] = photoUrl; // 【新增】

    await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }



  // 【新增】取得使用者頭像 (從 avatars 集合)
  Future<String?> getUserAvatar(String uid) async {
    try {
      final doc = await _db.collection('avatars').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['imageBase64'] as String?;
      }
    } catch (e) {
      print('取得頭像失敗: $e');
    }
    return null;
  }

  // 【新增】更新使用者頭像 (到 avatars 集合)
  Future<void> updateUserAvatar(String uid, String base64) async {
    try {
      await _db.collection('avatars').doc(uid).set({
        'imageBase64': base64,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('更新頭像失敗: $e');
    }
  }

  // 【修改】統一的 User 更新方法 (拆分頭像儲存)
  Future<void> updateUser(User user) async {
    // 1. 更新基本資料 (不含頭像)
    await syncUserData(
      nickname: user.nickname,
      hometown: user.hometown,
      height: user.height,
      weight: user.weight,
      age: user.age,
      bmi: user.bmi,
      fat: user.fat,
      gender: user.gender,
      bmr: user.bmr,
      goalWeight: user.goalWeight, // syncUserData 不再處理 photoUrl
    );

    // 2. 如果有頭像，另外存到 avatars 集合
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
       final currentUser = _auth.currentUser;
       if (currentUser != null) {
         await updateUserAvatar(currentUser.uid, user.photoUrl!);
       }
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final Map<String, Map<String, dynamic>> uniqueResults = {};

    try {
      final emailSnapshot = await _db.collection('users').where('email', isEqualTo: query).get();
      for (var doc in emailSnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        uniqueResults[doc['email']] = data;
      }
      
      final nicknameSnapshot = await _db.collection('users').where('nickname', isGreaterThanOrEqualTo: query).where('nickname', isLessThan: '$query\uf8ff').get();
      for (var doc in nicknameSnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        if (data.containsKey('email')) {
           uniqueResults[doc['email']] = data;
        }
      }
    } catch (e) {
      print('搜尋失敗: $e');
    }
    return uniqueResults.values.toList();
  }

  Future<Map<String, dynamic>?> getUserDataByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<void> addPost({required String title, required String content, String? imageBase64}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String authorName = user.email!.split('@')[0];
    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;
      if (data.containsKey('nickname') && data['nickname'].toString().isNotEmpty) {
        authorName = data['nickname'];
      }
    }

    await _db.collection('posts').add({
      'authorId': user.uid,
      'authorName': authorName,
      'title': title,
      'content': content,
      'imageUrl': imageBase64 ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    });
  }

  Stream<QuerySnapshot> getPostsStream() {
    return _db.collection('posts').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> deletePost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
      print('貼文已刪除');
    } catch (e) {
      print('刪除貼文失敗: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getUserPostsStream(String uid) {
    return _db.collection('posts').where('authorId', isEqualTo: uid).snapshots();
  }

  Future<void> saveWorkoutLog(WorkoutLog log) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).collection('workout_logs').add(log.toMap());
      print('訓練紀錄已備份至雲端');
    } catch (e) {
      print('訓練紀錄備份失敗: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> fetchBackedUpWorkoutLogs() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _db.collection('users').doc(user.uid).collection('workout_logs').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> saveWeightLog(WeightLog log) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).collection('weight_logs').add(log.toMap());
       print('體重紀錄已備份至雲端');
    } catch (e) {
      print('體重紀錄備份失敗: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBackedUpWeightLogs() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snapshot = await _db.collection('users').doc(user.uid).collection('weight_logs').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}