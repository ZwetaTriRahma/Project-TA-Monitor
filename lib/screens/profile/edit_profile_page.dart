import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nimController = TextEditingController();
  
  final _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isLoading = false;
  XFile? _pickedImage;
  String? _profileImageUrl;

  // --- KREDENSIAL CLOUDINARY ---
  final String _cloudinaryCloudName = 'dl7kvbaao';
  final String _cloudinaryApiKey = '526219655212682';
  final String _cloudinaryApiSecret = '0qXkgmo5hOPa32KxLBQ2rWc6s4U';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        _fullNameController.text = data['fullName'] ?? '';
        _nimController.text = data['nim'] ?? '';
        _profileImageUrl = data['profileImageUrl']; // Re-enable this
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedImageFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedImageFile != null) {
      setState(() {
        _pickedImage = pickedImageFile;
      });
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile image) async {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final signatureString = 'timestamp=$timestamp$_cloudinaryApiSecret';
      final signatureBytes = utf8.encode(signatureString);
      final signature = sha1.convert(signatureBytes).toString();

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = _cloudinaryApiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature;

      final bytes = await image.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'];
      } else {
        return null;
      }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? newImageUrl;
      if (_pickedImage != null) {
        newImageUrl = await _uploadImageToCloudinary(_pickedImage!);
        if (newImageUrl == null) {
          throw Exception('Failed to upload new profile picture.');
        }
      }

      Map<String, dynamic> dataToUpdate = {
        'fullName': _fullNameController.text.trim(),
        'nim': _nimController.text.trim(),
      };

      if (newImageUrl != null) {
        dataToUpdate['profileImageUrl'] = newImageUrl;
      }

      await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).update(dataToUpdate);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ImageProvider? _getImageProvider() {
    if (_pickedImage != null) {
      if (kIsWeb) {
        return NetworkImage(_pickedImage!.path);
      } else {
        return FileImage(File(_pickedImage!.path));
      }
    } else if (_profileImageUrl != null) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _getImageProvider(),
                        child: _getImageProvider() == null
                            ? const Icon(Icons.camera_alt, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap to change picture'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) => value!.isEmpty ? 'Please enter your full name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nimController,
                      decoration: const InputDecoration(labelText: 'NIM/NIDN'),
                      validator: (value) => value!.isEmpty ? 'Please enter your NIM/NIDN' : null,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
