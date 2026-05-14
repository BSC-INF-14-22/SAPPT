import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfilePage({super.key, required this.userData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _handleImageAction(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final File file = File(image.path);
      if (!await file.exists()) {
        throw Exception('File not found at ${image.path}');
      }

      final String? uid = widget.userData['uid'];
      if (uid == null) {
        throw Exception('User UID is missing. Please log in again.');
      }

      final String fileName = 'profile_$uid.jpg';
      
      // Fallback to the classic appspot.com bucket if firebasestorage.app fails
      // or try to use the default instance which should be pre-configured
      final storage = FirebaseStorage.instance;
      debugPrint('Current Storage Bucket in use: ${storage.bucket}');
      
      final storageRef = storage.ref().child('profile_pictures').child(fileName);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': uid},
      );

      debugPrint('Uploading to: ${storageRef.fullPath}');
      
      // Start upload task
      final uploadTask = storageRef.putFile(file, metadata);
      
      // Explicitly wait for the task to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      if (snapshot.state == TaskState.success) {
        debugPrint('Upload successful, fetching URL...');
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        
        debugPrint('Obtained URL: $downloadUrl');
        
        await FirestoreService().updateData('users', uid, {
          'photoUrl': downloadUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Upload task failed with state: ${snapshot.state}');
      }
    } catch (e, stackTrace) {
      debugPrint('UPLOAD ERROR: $e');
      debugPrint('STACKTRACE: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'INFO',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Troubleshooting'),
                    content: const Text(
                      'This error often happens if Storage is not enabled in Firebase Console. \n\n'
                      '1. Go to Firebase Console > Storage\n'
                      '2. Click "Get Started"\n'
                      '3. Set rules to allow read/write for auth users.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = widget.userData['photoUrl'];
    final name = widget.userData['fullName'] ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Profile Picture'),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundColor: theme.primaryColor.withAlpha(20),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        )
                      : null,
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              name,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.userData['role'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _handleImageAction(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('SELECT FROM GALLERY'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isLoading ? null : () => _handleImageAction(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('TAKE A PHOTO'),
            ),
          ],
        ),
      ),
    );
  }
}
