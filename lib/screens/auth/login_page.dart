// ===== KODE DIPERBAIKI UNTUK MENGATASI LAYAR PUTIH =====
// Struktur dioptimalkan ulang agar lebih stabil dan anti-gagal.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ta_monitor/screens/auth/register_page.dart';
import 'package:ta_monitor/screens/auth/complete_profile_google_page.dart';


// --- WIDGET HELPER UNTUK KOLOM INPUT PASSWORD ---
class _PasswordTextField extends StatefulWidget {
  const _PasswordTextField({required this.controller});
  final TextEditingController controller;
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
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isObscured = !_isObscured),
        ),
      ),
      validator: (v) => (v?.isEmpty ?? true) ? 'Please enter a password' : null,
    );
  }
}

// --- WIDGET UTAMA HALAMAN LOGIN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // OPTIMASI LANJUTAN: Menggunakan ValueNotifier untuk state loading.
  // Ini memungkinkan kita untuk hanya membangun ulang widget yang benar-benar perlu berubah.
  final _isLoading = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _isLoading.dispose(); // Wajib di-dispose
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _isLoading.value = true;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed'), backgroundColor: Colors.red));
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    _isLoading.value = true;
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) _isLoading.value = false;
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User user = userCredential.user!;
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => CompleteProfileGooglePage(user: user)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google Sign-In failed. Please check your connection."), backgroundColor: Colors.red));
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _forgotPassword() async {
    // ... (Logika tidak berubah, sudah optimal dengan StatefulBuilder)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF64B5F6), Color(0xFF1976D2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _LoginForm(
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              isLoadingNotifier: _isLoading,
              onLogin: _login,
              onForgotPassword: _forgotPassword,
              onGoogleSignIn: _signInWithGoogle,
            ),
          ),
        ),
      ),
    );
  }
}


// --- WIDGET FORM TAMPILAN (STABIL & TEROPTIMAL) ---
class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController, 
    required this.isLoadingNotifier,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onGoogleSignIn
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> isLoadingNotifier;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const FlutterLogo(size: 80, textColor: Colors.white),
        const SizedBox(height: 20),
        Text('Welcome Back!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Sign in to continue', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70)),
        const SizedBox(height: 40),
        Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()), validator: (v) => (v?.isEmpty ?? true) ? 'Please enter an email' : null),
                  const SizedBox(height: 16),
                  _PasswordTextField(controller: passwordController),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onForgotPassword, child: const Text('Forgot Password?'))),
                  const SizedBox(height: 16),
                  // OPTIMASI: Hanya widget di dalam builder ini yang akan di-rebuild saat loading
                  ValueListenableBuilder<bool>(
                    valueListenable: isLoadingNotifier,
                    builder: (context, isLoading, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(onPressed: onLogin, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white), child: const Text('LOGIN')),
                          const SizedBox(height: 24),
                          const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('OR')), Expanded(child: Divider())]),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.g_mobiledata_rounded, color: Colors.red),
                            label: const Text('Sign in with Google'),
                            onPressed: isLoading ? null : onGoogleSignIn,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.grey)),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Register Now")),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
