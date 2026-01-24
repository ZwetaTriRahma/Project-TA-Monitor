import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UploadFilePage extends StatefulWidget {
  const UploadFilePage({super.key});

  @override
  State<UploadFilePage> createState() => _UploadFilePageState();
}

class _UploadFilePageState extends State<UploadFilePage> {
  final _titleController = TextEditingController();
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  // Cloudinary credentials
  final String _cloudinaryCloudName = 'dl7kvbaao';
  final String _cloudinaryApiKey = '847986695727928';
  final String _cloudinaryApiSecret = 'BMwsVLv24SpRrzuo7_YA9PnC_ys';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.single;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_pickedFile == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title and pick a file.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final fileName = _pickedFile!.name;

      // Prepare for unsigned upload to Cloudinary
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/raw/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['api_key'] = _cloudinaryApiKey
        ..fields['upload_preset'] = 'default';

      if (kIsWeb) {
        if (_pickedFile!.bytes == null) throw Exception("File bytes are null on web");
        request.files.add(http.MultipartFile.fromBytes('file', _pickedFile!.bytes!, filename: fileName));
      } else {
        if (_pickedFile!.path == null) throw Exception("File path is null on mobile");
        request.files.add(await http.MultipartFile.fromPath('file', _pickedFile!.path!));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        debugPrint('Response JSON: $jsonMap');
        if (jsonMap.containsKey('error')) {
          throw Exception('Cloudinary error: ${jsonMap['error']['message']}');
        }
        final downloadUrl = jsonMap['secure_url'];
        debugPrint('Download URL: $downloadUrl');

        // [FIX] Save metadata to 'uploads' collection with 'userId'
        await FirebaseFirestore.instance.collection('uploads').add({
          'userId': user.uid,
          'title': _titleController.text.trim(),
          'fileName': fileName,
          'downloadUrl': downloadUrl,
          'status': 'Pending',
          'uploadedAt': Timestamp.now(),
          'feedback': ''
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
        Navigator.of(context).pop();

      } else {
        final responseData = await response.stream.toBytes();
        final responseString = String.fromCharCodes(responseData);
        debugPrint('Cloudinary response: $responseString');
        final jsonMap = jsonDecode(responseString);
        final errorMessage = jsonMap['error']?['message'] ?? 'Unknown error';
        throw Exception('Failed to upload to Cloudinary: $errorMessage');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload New File'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'File Title (e.g., Chapter 1)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: Text(_pickedFile == null ? 'Pick a File (.pdf, .doc)' : _pickedFile!.name),
              onPressed: _pickFile,
            ),
            const SizedBox(height: 20),
            _isUploading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Upload'),
                  onPressed: _uploadFile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
