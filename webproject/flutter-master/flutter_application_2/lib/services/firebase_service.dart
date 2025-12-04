import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload image to Firebase Storage
  Future<String?> uploadImage(XFile file, String folder) async {
    try {
      // Create a unique filename
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child('$folder/$fileName');

      // Upload the file
      final bytes = await file.readAsBytes();
      UploadTask uploadTask = ref.putData(bytes);
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      // print('Error uploading image: $e');
      return null;
    }
  }

  // Save user image URL to Firestore
  Future<bool> saveUserImageToFirestore(String userId, String imageUrl) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'avatarUrl': imageUrl,
      });
      return true;
    } catch (e) {
      // print('Error saving to Firestore: $e');
      return false;
    }
  }

  // Save image metadata to 'image' collection
  Future<void> saveImageMetadata(
    String imageUrl, {
    String? caption,
    String? username,
  }) async {
    try {
      await _firestore.collection('image').add({
        'image': imageUrl,
        'created_at': FieldValue.serverTimestamp(),
        if (caption != null) 'caption': caption,
        if (username != null) 'username': username,
      });
      // print('Image metadata saved to Firestore');
    } catch (e) {
      // print('Error saving image metadata: $e');
      rethrow;
    }
  }
}
