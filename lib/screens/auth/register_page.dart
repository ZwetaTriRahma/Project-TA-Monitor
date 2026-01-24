import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class _PasswordTextField extends StatefulWidget {
  const _PasswordTextField({
    required this.controller,
    required this.labelText,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final FormFieldValidator<String>? validator;

  @override
  State<_PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<_PasswordTextField> {
  bool _isObscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _isObscured,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isObscured = !_isObscured),
        ),
      ),
      validator: widget.validator,
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _idNumberController = TextEditingController();

  bool _isLoading = false;
  String? _selectedRole;
  String? _selectedFaculty;
  String? _selectedMajor;
  String? _selectedLecturerId;

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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _onRoleChanged(String? newValue) {
    setState(() {
        _selectedRole = newValue;
        _selectedFaculty = null;
        _selectedMajor = null;
        _selectedLecturerId = null;
    });
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

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userData = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false, // Default verification status
        'isDisabled': false, // Default disabled status
        if (_selectedRole == 'Mahasiswa' || _selectedRole == 'Dosen') ...{
           'faculty': _selectedFaculty,
           'major': _selectedMajor,
           'nim_or_nidn': _idNumberController.text.trim(),
        },
        if (_selectedRole == 'Mahasiswa' && _selectedLecturerId != null) 'lecturerId': _selectedLecturerId,
      };

      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful! Your account is pending verification by an admin.')));
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Registration failed')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage("assets/images/campus_background.png"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Color.fromRGBO(0, 0, 0, 0.6), BlendMode.darken),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 50.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Create Account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Join the community', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 40),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(controller: _fullNameController, decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Enter your full name' : null),
                          const SizedBox(height: 16),
                          TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Enter an email' : null),
                          const SizedBox(height: 16),
                          _PasswordTextField(controller: _passwordController, labelText: 'Password', validator: (v) => v!.length < 6 ? 'Min. 6 characters' : null),
                          const SizedBox(height: 16),
                          _PasswordTextField(controller: _confirmPasswordController, labelText: 'Confirm Password', validator: (v) => v!.isEmpty ? 'Confirm your password' : null),
                          const SizedBox(height: 16),
                          // [MODIFIED] Removed 'Admin' from the list of roles
                          DropdownButtonFormField<String>(initialValue: _selectedRole, hint: const Text('Select Role'), items: ['Mahasiswa', 'Dosen'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: _onRoleChanged, decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a role' : null),
                          if (_selectedRole == 'Mahasiswa' || _selectedRole == 'Dosen') ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(initialValue: _selectedFaculty, hint: const Text('Select Faculty'), items: _majorsByFaculty.keys.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(), onChanged: _onFacultyChanged, decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a faculty' : null),
                            if (_selectedFaculty != null) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(initialValue: _selectedMajor, hint: const Text('Select Major'), items: _majors.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: _onMajorChanged, decoration: const InputDecoration(border: OutlineInputBorder()), validator: (v) => v == null ? 'Select a major' : null),
                            ],
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
                                  validator: (v) => v == null ? 'Please select a lecturer' : null,
                                  isExpanded: true,
                                ),
                          ],
                          const SizedBox(height: 32),
                          _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _register, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('REGISTER')),
                        ],
                      ),
                    ),
                  ),
                ),
                 Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Login Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
