import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CompleteProfileGooglePage extends StatefulWidget {
  final User user;
  const CompleteProfileGooglePage({super.key, required this.user});

  @override
  State<CompleteProfileGooglePage> createState() => _CompleteProfileGooglePageState();
}

class _CompleteProfileGooglePageState extends State<CompleteProfileGooglePage> {
  final _formKey = GlobalKey<FormState>();
  final _idNumberController = TextEditingController();

  // State
  String? _selectedRole;
  String? _selectedFaculty;
  String? _selectedMajor;
  String? _selectedLecturerId;
  bool _isLoading = false;

  // Data
  final Map<String, List<String>> _majorsByFaculty = {
    'Fakultas Teknik': ['Teknik Informatika', 'Teknik Elektro', 'Teknik Mesin'],
    'Fakultas Ekonomi': ['Akuntansi', 'Manajemen'],
    'Fakultas Ilmu Sosial dan Ilmu Politik': ['Ilmu Komunikasi', 'Administrasi Publik'],
  };
  List<String> _majors = [];
  List<Map<String, String>> _lecturers = [];
  bool _isFetchingLecturers = false;

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  void _onFacultyChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedFaculty = newValue;
      _majors = _majorsByFaculty[newValue] ?? [];
      _selectedMajor = null;
      _lecturers = [];
      _selectedLecturerId = null;
    });
  }

  void _onMajorChanged(String? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedMajor = newValue;
      _lecturers = [];
      _selectedLecturerId = null;
    });
    if (_selectedRole == 'Mahasiswa') {
      _fetchLecturers(newValue);
    }
  }

  Future<void> _fetchLecturers(String major) async {
    setState(() => _isFetchingLecturers = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Dosen')
          .where('major', isEqualTo: major)
          .get();
      final lecturers = querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['fullName'] as String? ?? 'Unnamed Lecturer'
      }).toList();
      if(mounted) setState(() => _lecturers = lecturers);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to fetch lecturers: $e")));
    } finally {
      if(mounted) setState(() => _isFetchingLecturers = false);
    }
  }

  Future<void> _completeProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final userData = {
        'fullName': widget.user.displayName ?? 'New User',
        'email': widget.user.email,
        'profileImageUrl': widget.user.photoURL,
        'role': _selectedRole,
        'faculty': _selectedFaculty,
        'major': _selectedMajor,
        'nim_or_nidn': _idNumberController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        if (_selectedRole == 'Mahasiswa' && _selectedLecturerId != null) 'lecturerId': _selectedLecturerId,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set(userData);
    } catch (e) {
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save profile: $e")));
    } finally {
       if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if(widget.user.photoURL != null)
                  CircleAvatar(radius: 40, backgroundImage: NetworkImage(widget.user.photoURL!)),
                const SizedBox(height: 16),
                Text('Welcome, ${widget.user.displayName}!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Just one more step to get started.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),

                // -- Form Fields --
                DropdownButtonFormField<String>(initialValue: _selectedRole, hint: const Text('Select Your Role'), items: ['Mahasiswa', 'Dosen'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (val) => setState(() => _selectedRole = val), decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a role' : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(initialValue: _selectedFaculty, hint: const Text('Select Your Faculty'), items: _majorsByFaculty.keys.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: _onFacultyChanged, decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a faculty' : null),
                if (_selectedFaculty != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(initialValue: _selectedMajor, hint: const Text('Select Your Major'), items: _majors.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: _onMajorChanged, decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a major' : null),
                ],
                if (_selectedRole != null) ...[
                    const SizedBox(height: 16),
                  TextFormField(controller: _idNumberController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _selectedRole == 'Mahasiswa' ? 'NIM' : 'NIDN', border: const OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Enter your ID Number' : null),
                ],
                if (_selectedRole == 'Mahasiswa' && _selectedMajor != null) ...[
                  const SizedBox(height: 16),
                  _isFetchingLecturers
                      ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedLecturerId,
                          hint: const Text('Select Supervising Lecturer'),
                          items: _lecturers.map((lec) => DropdownMenuItem(value: lec['id'], child: Text(lec['name']!))).toList(),
                          onChanged: (value) => setState(() => _selectedLecturerId = value),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          validator: (value) => value == null ? 'Please select a lecturer' : null,
                          isExpanded: true,
                        ),
                ],
                // -- End of Form Fields --

                const SizedBox(height: 32),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _completeProfile, 
                        child: const Text('Finish & Continue')
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
