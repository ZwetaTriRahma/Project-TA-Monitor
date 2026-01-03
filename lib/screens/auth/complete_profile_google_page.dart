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
  String? _selectedRole;
  final _roles = ['Mahasiswa', 'Dosen'];

  String? _selectedLecturerId;
  List<Map<String, String>> _lecturers = [];
  bool _isFetchingLecturers = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Langsung fetch daftar dosen karena kemungkinan besar pengguna adalah mahasiswa
    _fetchLecturers();
  }

  Future<void> _fetchLecturers() async {
    setState(() => _isFetchingLecturers = true);
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Dosen').get();
      final lecturers = querySnapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['fullName'] as String? ?? 'Unnamed Lecturer'
      }).toList();
      if(mounted) setState(() => _lecturers = lecturers);
    } finally {
      if(mounted) setState(() => _isFetchingLecturers = false);
    }
  }

  void _onRoleChanged(String? newValue) {
    setState(() => _selectedRole = newValue);
    if (newValue != 'Mahasiswa') {
      setState(() => _selectedLecturerId = null);
    }
  }

  Future<void> _completeProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final userData = {
        'fullName': widget.user.displayName ?? 'New User',
        'email': widget.user.email,
        'role': _selectedRole,
        if (_selectedRole == 'Mahasiswa' && _selectedLecturerId != null) 'lecturerId': _selectedLecturerId,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set(userData);
      // AuthWrapper akan otomatis mengarahkan setelah data dibuat
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
        automaticallyImplyLeading: false, // Menghilangkan tombol kembali
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Welcome, ${widget.user.displayName}!', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Just one more step to get started.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                // --- Input Pilihan Peran ---
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  hint: const Text('Select Your Role'),
                  items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                  onChanged: _onRoleChanged,
                  decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline)),
                  validator: (value) => value == null ? 'Please select a role' : null,
                ),
                // --- Muncul jika peran adalah Mahasiswa ---
                if (_selectedRole == 'Mahasiswa') ...[
                  const SizedBox(height: 16),
                  _isFetchingLecturers
                      ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                      : DropdownButtonFormField<String>(
                          value: _selectedLecturerId,
                          hint: const Text('Select Your Lecturer'),
                          items: _lecturers.map((lec) => DropdownMenuItem(value: lec['id'], child: Text(lec['name']!))).toList(),
                          onChanged: (value) => setState(() => _selectedLecturerId = value),
                          decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.school_outlined)),
                          validator: (value) => value == null ? 'Please select a lecturer' : null,
                        ),
                ],
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
