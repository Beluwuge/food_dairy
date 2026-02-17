import 'package:flutter/material.dart';

import 'services/google_auth_helper.dart';
import 'services/shared_preference_helper.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:food_dairy/registration/register.dart';
import 'welcome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Login',
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgSecondary = Color(0xFF121212);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const accentPrimary = Color(0xFF0095F6);
  static const divider = Color(0xFF2A2A2E);
}

class _Dimens {
  static const pagePadding = EdgeInsets.all(24);
  static const fieldPadding = EdgeInsets.all(16);
  static const buttonVPadding = EdgeInsets.symmetric(vertical: 16);
  static const r8 = 8.0;
  static const gap8 = SizedBox(height: 8);
  static const gap12 = SizedBox(height: 12);
  static const gap16 = SizedBox(height: 16);
  static const gap24 = SizedBox(height: 24);
  static const gap48 = SizedBox(height: 48);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _checkingSession = false;
  bool _loading = false;

  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() => _checkingSession = true);

    // TODO: Implement your session restore logic using SharedPreferenceHelper.
    // If session exists, navigate to your welcome/home screen.

    if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      // TODO: Implement login logic.
      // On success, navigate to welcome/home.

      if (!mounted) return;
      // Example navigation (adjust to your actual widget/class names):
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      // );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final userCredential = await signInWithGoogle();

      print("User signed in: ${userCredential.user?.email}");

      // Navigate after login
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Sign in error: $e");
    }
  }

  void _goToRegister() {
    // Adjust the target widget/class name to match your register.dart.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RegistrationPage()),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: _Spinner()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: _Dimens.pagePadding,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: AbsorbPointer(
                    absorbing: _loading,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dimens.gap12,
                        const _Header(),
                        _Dimens.gap48,
                        _Input(
                          controller: _usernameCtrl,
                          hintText: 'Username',
                          obscureText: false,
                          textInputAction: TextInputAction.next,
                        ),
                        _Dimens.gap16,
                        _Input(
                          controller: _passwordCtrl,
                          hintText: 'Password',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        _Dimens.gap8,
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: _Styles.primaryButtonStyle(),
                            child: _loading
                                ? const _Spinner()
                                : const Text(
                              'Log In',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _Dimens.gap24,
                        const _DividerOr(),
                        _Dimens.gap24,
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleGoogleLogin,
                            style: _Styles.googleButtonStyle(),
                            icon: const Icon(
                              Icons.g_mobiledata,
                              color: AppColors.textPrimary,
                              size: 28,
                            ),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        _Dimens.gap24,
                        TextButton(
                          onPressed: _goToRegister,
                          child: const Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(
                                    color: AppColors.accentPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Spacer(),
                        _Dimens.gap12,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Styles {
  static ButtonStyle primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.accentPrimary,
      padding: _Dimens.buttonVPadding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Dimens.r8),
      ),
      disabledBackgroundColor: AppColors.accentPrimary.withOpacity(0.6),
    );
  }

  static ButtonStyle googleButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: _Dimens.buttonVPadding,
      side: const BorderSide(color: AppColors.divider, width: 1),
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Dimens.r8),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.restaurant, size: 64, color: AppColors.textPrimary),
        SizedBox(height: 16),
        Text(
          'FoodDiary',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _Input({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgElevated,
        contentPadding: _Dimens.fieldPadding,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Dimens.r8),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_Dimens.r8),
          borderSide: const BorderSide(color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}

class _DividerOr extends StatelessWidget {
  const _DividerOr();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ],
    );
  }
}
