
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ta_monitor/screens/auth/admin_login_page.dart'; // Import admin login page
import 'package:ta_monitor/screens/auth/register_page.dart';
import 'package:ta_monitor/screens/auth/complete_profile_google_page.dart';
import 'package:ta_monitor/screens/home/dosen_dashboard_page.dart';
import 'package:ta_monitor/screens/home/home_page.dart';

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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: Colors.white),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: () => setState(() => _isObscured = !_isObscured),
        ),
      ),
      validator: (v) => (v?.isEmpty ?? true) ? 'Please enter a password' : null,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _isLoading = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _handleLoginSuccess(User user) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;

    // This should ideally not be reached if AuthWrapper is set up correctly,
    // but as a fallback, we direct to profile completion.
    if (!userDoc.exists) {
       Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => CompleteProfileGooglePage(user: user)));
      return;
    }

    final role = userDoc.data()?['role'];
    
    // [FIX] Prevent Admins from logging in here and ensure they are signed out.
    if (role == 'Admin') {
      await FirebaseAuth.instance.signOut();
      if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admins must use the dedicated admin login page.'), backgroundColor: Colors.red),
          );
      }
      // By returning here, we stop navigation and let the AuthWrapper handle the signed-out state, 
      // which should keep the user on the login page.
      return; 
    }

    // Navigate based on a valid role.
    switch (role) {
      case 'Dosen':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const DosenDashboardPage()));
        break;
      case 'Mahasiswa':
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomePage()));
        break;
      default:
        // If role is null or unrecognized, sign out and show an error.
        await FirebaseAuth.instance.signOut();
         if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your user role is not recognized. Please contact support.'), backgroundColor: Colors.red),
            );
        }
    }
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _isLoading.value = true;
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null) {
        await _handleLoginSuccess(userCredential.user!);
      }
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

      if (userCredential.user != null) {
        await _handleLoginSuccess(userCredential.user!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In failed. Please try again."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) _isLoading.value = false;
    }
  }

  Future<void> _forgotPassword() {
    // ...
    return Future.value();
  }

  void _showUsageGuide(BuildContext context) {
    // ...
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(image: AssetImage("assets/images/campus_background.png"), fit: BoxFit.cover),
            ),
          ),
          Container(color: const Color.fromRGBO(0, 0, 0, 0.5)),
          Center(
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
                onShowUsage: () => _showUsageGuide(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController, 
    required this.isLoadingNotifier,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
    required this.onShowUsage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final ValueNotifier<bool> isLoadingNotifier;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onShowUsage;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.school, size: 80, color: Colors.white),
        const SizedBox(height: 20),
        Text(
          'DI-Monitoring',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Web Application Monitoring Tugas Akhir Mahasiswa',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        Text(
          'Universitas Bina Bangsa',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 40),

        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Please enter an email' : null,
                    ),
                    const SizedBox(height: 16),
                    _PasswordTextField(controller: passwordController),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onForgotPassword, style: TextButton.styleFrom(foregroundColor: Colors.white70), child: const Text('Forgot Password?'))),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<bool>(
                      valueListenable: isLoadingNotifier,
                      builder: (context, isLoading, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(onPressed: onLogin, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('LOGIN')),
                            const SizedBox(height: 24),
                            const Row(children: [Expanded(child: Divider(color: Colors.white54)), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('OR', style: TextStyle(color: Colors.white))), Expanded(child: Divider(color: Colors.white54))]),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: Image.asset('assets/google_logo.png', height: 20),
                              label: const Text('Sign in with Google'),
                              onPressed: isLoading ? null : onGoogleSignIn,
                              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, side: const BorderSide(color: Colors.grey)),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                        TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Register Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AdminLoginPage())),
                        child: const Text("Login as Admin", style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(onPressed: onShowUsage, child: const Text("Tata Cara Penggunaan", style: TextStyle(color: Colors.white)))
      ],
    );
  }
}
