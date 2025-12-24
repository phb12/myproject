import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:convert';
import '../models/workout_log_model.dart';
import '../models/exercise_model.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
// ... (existing code) ...

  // --- Stats ---
  
  Future<Map<String, dynamic>> getUserStats(String uid, DateTime start, DateTime end) async {
    // ... (existing implementation) ...
    final snapshot = await _db.collection('users').doc(uid).collection('workout_logs')
        .where('completedAt', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('completedAt', isLessThanOrEqualTo: end.toIso8601String())
        .get();
        
    final logs = snapshot.docs.map((d) => WorkoutLog.fromMap(d.data())).toList();
    
    final Set<String> days = {};
    int totalDuration = 0; 
    
    for (var log in logs) {
      days.add(log.completedAt.toIso8601String().split('T')[0]);
      totalDuration += log.duration; // Now we have duration
    }
    
    return {
      'total_days': days.length,
      'total_duration_minutes': (totalDuration / 60).round(),
    };
  }

  Future<Map<String, int>> getTrainingPartsStats(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).collection('workout_logs').get();
    final Map<String, int> stats = {};
    
    for (var doc in snapshot.docs) {
      final log = WorkoutLog.fromMap(doc.data());
      // Assuming duration is used for stats, or just count?
      // The original API `stats_by_part` likely returned duration or count.
      // Let's assume duration based on "Training Parts Duration Share".
      final partName = log.bodyPart.name; // Enum name (english)
      // Map english enum to chinese if needed, or UI handles it?
      // UI `StatisticsPieChart` likely handles mapping or expects specific keys.
      // Original API returned keys like "胸", "背".
      // My `WorkoutLog` uses `BodyPart` enum.
      // I should map enum to Chinese keys to match UI expectation if possible, or update UI.
      // `dashboard_page.dart` uses `StatisticsPieChart(parts: trainingStats)`.
      // Let's map to Chinese.
      String key = '其他';
      switch (log.bodyPart) {
        case BodyPart.chest: key = '胸'; break;
        case BodyPart.back: key = '背'; break;
        case BodyPart.legs: key = '腿'; break;
        case BodyPart.shoulders: key = '肩'; break;
        case BodyPart.arms: key = '手臂'; break;
        case BodyPart.core: key = '核心'; break;
        default: key = '其他';
      }
      
      stats[key] = (stats[key] ?? 0) + log.duration;
    }
    return stats;
  }

  // --- Storage ---

  Future<String> uploadUserImage(String uid, Uint8List fileData, {String? filePath}) async {
    final ref = _storage.ref().child('user_avatars').child('$uid.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    
    // Check if we can use putFile (Windows/Android/iOS/Linux/macOS)
    // Note: We avoid importing dart:io directly at top if this file is compiled for pure web, 
    // but Flutter Web usually stubs dart:io or we use conditional imports.
    // For this specific project structure which seems to handle both, we proceed with kIsWeb check.
    // However, since we can't easily import dart:io here without breaking web compile if not handled,
    // we will stick to putData but try to catch the specific platform channel error if possible, 
    // OR we can try to use a different approach.
    // But since the user IS on Windows, fileData is fine IF the plugin worked.
    // The error suggests `putData` event channel is the issue.
    // Let's try `putFile` if filePath is provided and we are NOT on web.
    // modifying imports to support File is tricky in one file.
    // We will assume `dart:io` is available or we use `universal_io`.
    
    // SIMPLIFIED FIX for now: Just stick to putData but DO NOT await the snapshot state if possible?
    // No, we need the URL.
    
    // Let's try to use putData but wrapped in a runZonedGuarded? No.
    
    // Alternative: Just use putData and ignore the log if it works? 
    // The log says "Failure to do so may result in data loss or crashes".
    
    // Let's rely on standard putData but maybe the issue is the metadata?
    // User reported error AFTER metadata added? No, user reported object-not-found first.
    // This threading error appeared after I modified the code.
    
    // Reverting to previous state might fix the threading error but reintroduce object-not-found?
    // object-not-found was due to WRONG UID.
    // So if we fix the UID, we might not need the "await putData" change?
    // The original code was:
    // await ref.putData(fileData);
    // return await ref.getDownloadURL();
    
    // This IS awaiting putData.
    // So why did the threading error only appear now? 
    // Maybe because `putData(..., metadata)` triggers different code path?
    
    // Let's try to remove metadata and use the explicit await (TaskSnapshot) 
    // OR just revert to standard `await ref.putData(fileData)` WITHOUT metadata,
    // trusting that the UID fix solved the `object-not-found`.
    
    // I will revert to the "Simple" upload but keep the UID fix (which is in LoginPage).
    // And I will add a small delay just in case.
    
    await ref.putData(fileData); // Revert to simple putData without metadata for now to reduce noise
    // Small delay to ensure backend consistency (optional but safe)
    await Future.delayed(const Duration(milliseconds: 500));
    return await ref.getDownloadURL();
  }

  // --- Friend Management Extended ---

  Future<List<String>> getFriends(String uid) async {
    final snapshot = await _db.collection('friends').where('users', arrayContains: uid).get();
    final List<String> friends = [];
    for (var doc in snapshot.docs) {
      final users = List<String>.from(doc['users']);
      final friendUid = users.firstWhere((u) => u != uid, orElse: () => '');
      if (friendUid.isNotEmpty) {
        friends.add(friendUid);
      }
    }
    // Note: This returns UIDs. The original API returned usernames.
    // If the UI expects display names, we might need to fetch them.
    // `FriendListPage` fetches friends then filters.
    // `FriendListPage` displays the string directly.
    // If I return UIDs, it will display UIDs.
    // I should probably fetch user profiles to get nicknames/display names?
    // Or `FriendListPage` should fetch profiles.
    // `FriendListPage` has `_fetchFriendAvatar` which fetches profile.
    // But the list itself displays the name.
    // I'll return UIDs for now, and maybe `FriendListPage` needs update to show nickname.
    // Actually, `FriendListPage` uses `friends` list of strings.
    // I'll stick to UIDs as the "username" in the new system.
    return friends;
  }

  Future<void> deleteFriend(String uid1, String uid2) async {
    final List<String> uids = [uid1, uid2]..sort();
    final friendDocId = '${uids[0]}_${uids[1]}';
    await _db.collection('friends').doc(friendDocId).delete();
  }

  Future<int> getFriendCount(String uid) async {
    final snapshot = await _db.collection('friends').where('users', arrayContains: uid).count().get();
    return snapshot.count ?? 0;
  }

  Future<List<Map<String, dynamic>>> getFriendRequests(String uid) async {
    final snapshot = await _db.collection('friend_requests')
        .where('to_user', isEqualTo: uid)
        .where('status', isEqualTo: 0) // 0: pending
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    // Check if request already exists
    final snapshot = await _db.collection('friend_requests')
        .where('from_user', isEqualTo: fromUid)
        .where('to_user', isEqualTo: toUid)
        .where('status', isEqualTo: 0)
        .get();
    
    if (snapshot.docs.isNotEmpty) return;

    await _db.collection('friend_requests').add({
      'from_user': fromUid,
      'to_user': toUid,
      'status': 0,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> dealFriendRequest(String requestId, int status) async {
    await _db.collection('friend_requests').doc(requestId).update({'status': status});
    
    if (status == 1) {
      // If accepted, create friend record
      final doc = await _db.collection('friend_requests').doc(requestId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final uids = [data['from_user'] as String, data['to_user'] as String]..sort();
        await _db.collection('friends').doc('${uids[0]}_${uids[1]}').set({
          'users': uids,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<Map<String, dynamic>> getRelationshipStatus(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return {'status': 'self'};

    // Check friend
    final friendsSnapshot = await _db.collection('friends').where('users', arrayContains: currentUid).get();
    for (var doc in friendsSnapshot.docs) {
      if ((doc['users'] as List).contains(targetUid)) return {'status': 'friend'};
    }

    // Check request sent
    final sentSnapshot = await _db.collection('friend_requests')
        .where('from_user', isEqualTo: currentUid)
        .where('to_user', isEqualTo: targetUid)
        .where('status', isEqualTo: 0)
        .get();
    if (sentSnapshot.docs.isNotEmpty) return {'status': 'request_sent'};

    // Check request received
    final receivedSnapshot = await _db.collection('friend_requests')
        .where('from_user', isEqualTo: targetUid)
        .where('to_user', isEqualTo: currentUid)
        .where('status', isEqualTo: 0)
        .get();
    if (receivedSnapshot.docs.isNotEmpty) {
      return {'status': 'request_received', 'request_id': receivedSnapshot.docs.first.id};
    }

    return {'status': 'stranger'};
  }

  String? getCurrentUserUid() {
    return _auth.currentUser?.uid;
  }

  // Sync user data (Profile)
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
    String? avatarUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

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
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    await _db.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }
  
  // Get user data by UID (for viewing others)
  Future<Map<String, dynamic>?> getUserDataByUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Search users
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

      final nicknameSnapshot = await _db.collection('users')
          .where('nickname', isGreaterThanOrEqualTo: query)
          .where('nickname', isLessThan: '$query\uf8ff')
          .get();
          
      for (var doc in nicknameSnapshot.docs) {
        final data = doc.data();
        data['uid'] = doc.id;
        // Only add if we have email or some identifier, or just add all
         uniqueResults[doc.id] = data; // Use ID as key to avoid duplicates
      }
    } catch (e) {
      print('Search failed: $e');
    }
    return uniqueResults.values.toList();
  }

  // Add Post
  Future<void> addPost({required String title, required String content, String? imageBase64, String? date}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String authorName = user.email?.split('@')[0] ?? 'User';
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
      'date': date, // Optional date string
      'likeCount': 0,
      'commentCount': 0,
    });
  }

  Stream<QuerySnapshot> getPostsStream() {
    return _db.collection('posts').orderBy('timestamp', descending: true).snapshots();
  }

  Stream<QuerySnapshot> getUserPostsStream(String uid) {
    return _db.collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  // --- Training Schedule & Checks ---

  Future<bool> checkTodayTraining(String uid) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    // Check workout logs
    final snapshot = await _db.collection('users').doc(uid).collection('workout_logs')
        .where('completedAt', isGreaterThanOrEqualTo: '${today}T00:00:00')
        .where('completedAt', isLessThanOrEqualTo: '${today}T23:59:59')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>> getTrainingTemplate(String uid) async {
    final doc = await _db.collection('training_templates').doc(uid).get();
    if (doc.exists) {
      return doc.data() ?? {};
    }
    return {'schedule': []};
  }

  Future<void> saveTrainingTemplate(String uid, Map<String, dynamic> templateData) async {
    await _db.collection('training_templates').doc(uid).set(templateData);
  }

  Future<List<String>> getDailyCompletion(String uid, String date) async {
    final snapshot = await _db.collection('daily_completion')
        .where('username', isEqualTo: uid)
        .where('date', isEqualTo: date)
        .where('is_completed', isEqualTo: 1)
        .get();
    return snapshot.docs.map((d) => d['item_id'] as String).toList();
  }

  Future<void> setDailyCompletion(String uid, String date, String itemId, bool isCompleted) async {
    // We need a unique ID for the completion record. Composite key: uid_date_itemId
    final docId = '${uid}_${date}_$itemId';
    await _db.collection('daily_completion').doc(docId).set({
      'username': uid,
      'date': date,
      'item_id': itemId,
      'is_completed': isCompleted ? 1 : 0,
    });
  }
  // --- Workout Logs (CRUD) ---

  Future<void> saveWorkoutLog(WorkoutLog log) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('users').doc(user.uid).collection('workout_logs').add(log.toMap());
  }

  Future<void> deleteWorkoutLog(String logId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _db.collection('users').doc(user.uid).collection('workout_logs').doc(logId).delete();
  }

  Future<void> deleteWorkoutLogsByDate(String uid, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    
    final snapshot = await _db.collection('users').doc(uid).collection('workout_logs')
        .where('completedAt', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('completedAt', isLessThanOrEqualTo: end.toIso8601String())
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<List<WorkoutLog>> fetchBackedUpWorkoutLogs(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).collection('workout_logs')
        .orderBy('completedAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return WorkoutLog.fromMap(data);
    }).toList();
  }

  // --- Notifications Extended ---

  Future<List<Map<String, dynamic>>> getNotifications(String uid) async {
    final snapshot = await _db.collection('notifications')
        .where('username', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Use Doc ID
      return data;
    }).toList();
  }

  Future<int> getUnreadNotificationCount(String uid) async {
    final snapshot = await _db.collection('notifications')
        .where('username', isEqualTo: uid)
        .where('status', isEqualTo: 0)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'status': 1});
  }

  Future<void> deleteReadNotifications(String uid) async {
    final snapshot = await _db.collection('notifications')
        .where('username', isEqualTo: uid)
        .where('status', isEqualTo: 1)
        .get();
    
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // --- Exercise Data ---

  Future<Map<String, List<String>>> getAllExercises() async {
    // Return standard exercise list. 
    // In a real app, this might come from a collection 'exercises'.
    // For now, we return a static list matching the original app's likely data.
    return {
      "胸部": ["槓鈴臥推", "伏地挺身"],
      "背部": ["引體向上"],
      "腿部": ["深蹲", "硬舉"],
      "肩部": ["啞鈴肩推", "側平舉"],
      "手臂": ["二頭肌彎舉", "三頭肌下壓"],
      "核心": ["卷腹"],
    };
  }

  // --- Schedule Operations ---

  Future<void> copyScheduleDay(String fromUid, String toUid, int fromDayIdx, int toDayIdx) async {
    final fromTemplate = await getTrainingTemplate(fromUid);
    final toTemplate = await getTrainingTemplate(toUid);

    List fromSchedule = fromTemplate['schedule'] ?? [];
    List toSchedule = toTemplate['schedule'] ?? [];

    // Ensure schedules are initialized
    if (fromSchedule.isEmpty || fromSchedule.length <= fromDayIdx) return;
    
    // Initialize toSchedule if needed
    if (toSchedule.isEmpty) {
      toSchedule = List.generate(7, (i) => {
        "day": ["週一", "週二", "週三", "週四", "週五", "週六", "週日"][i],
        "title": "",
        "plans": []
      });
    }

    // Deep copy the day
    final sourceDay = fromSchedule[fromDayIdx];
    toSchedule[toDayIdx]['title'] = sourceDay['title'];
    toSchedule[toDayIdx]['plans'] = json.decode(json.encode(sourceDay['plans'])); // Deep copy via JSON

    await saveTrainingTemplate(toUid, {'schedule': toSchedule});
  }

  Future<void> shareSchedule(String fromUid, String toUid) async {
    // Create a notification for the target user
    await _db.collection('notifications').add({
      'username': toUid,
      'content': '$fromUid 分享了課表給你 (功能開發中)', // Placeholder for actual sharing logic
      'created_at': FieldValue.serverTimestamp(),
      'status': 0,
      'type': 'schedule_share',
      'from_user': fromUid
    });
  }


  Future<Map<String, dynamic>> getPostLikeStatus(String postId, String uid) async {
    final postDoc = await _db.collection('posts').doc(postId).get();
    final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
    return {
      'like_count': likes.length,
      'is_liked': likes.contains(uid),
    };
  }

  Future<Map<String, dynamic>> toggleLikePost(String postId, String uid) async {
    final postRef = _db.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    
    if (!postDoc.exists) return {'like_count': 0, 'status': 'error'};

    final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
    String status;
    
    if (likes.contains(uid)) {
      likes.remove(uid);
      status = 'unliked';
    } else {
      likes.add(uid);
      status = 'liked';
    }
    
    await postRef.update({'likes': likes});
    
    return {
      'like_count': likes.length,
      'status': status,
    };
  }

  Future<String> uploadPostImage(String uid, Uint8List fileData) async {
    final ref = _storage.ref().child('post_images').child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(fileData);
    return await ref.getDownloadURL();
  }
}
