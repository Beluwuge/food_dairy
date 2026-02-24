import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'services/shared_preference_helper.dart';
import 'package:food_dairy/registration/register.dart';
import 'profile.dart';

Future<void> main() async {
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
  static const danger = Color(0xFFFF453A);
  static const success = Color(0xFF30D158);
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
  // Existing controllers (integrated)
  final accountName = TextEditingController();
  final accountPass = TextEditingController();
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  bool _checkingSession = false;
  bool _loading = false;

  String displayTxt = "";
  Color _displayColor = AppColors.textSecondary;

  void updateDisplay(String txt, {bool isError = true}) {
    setState(() {
      displayTxt = txt;
      _displayColor = isError ? AppColors.danger : AppColors.success;
    });
  }

  @override
  void initState() {
    super.initState();

    analytics.logScreenView(
      screenName: 'login_screen',
      screenClass: 'LoginScreen',
    );

    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() => _checkingSession = true);

    // If your SharedPreferenceHelper supports a "current user"/session flag,
    // you can restore & navigate here. Keeping it safe/no-op by default.

    if (mounted) setState(() => _checkingSession = false);
  }

  Future<void> _handleLogin() async {
    if (_loading) return;

    final nameInput = accountName.text.trim();
    final passInput = accountPass.text;

    setState(() => _loading = true);

    try {
      // GA4: user activity (button press)
      await analytics.logEvent(
        name: 'login_button_press',
        parameters: {
          'screen': 'login',
          'has_username': nameInput.isNotEmpty ? 1 : 0,
        },
      );

      final Map<String, dynamic> userData =
      await SharedPreferenceHelper.getMap("userlist");

      // Optional: inspect stored structure (remove later)
      debugPrint('userlist keys: ${userData.keys}');
      debugPrint('user record for $nameInput: ${userData[nameInput]}');

      if (nameInput.isEmpty || passInput.isEmpty) {
        await analytics.logEvent(
          name: 'login_failed',
          parameters: {'reason': 'empty_fields', 'screen': 'login'},
        );
        updateDisplay("username or Password cannot be empty.");
        return;
      }

      if (!userData.containsKey(nameInput)) {
        await analytics.logEvent(
          name: 'login_failed',
          parameters: {'reason': 'wrong_username', 'screen': 'login'},
        );
        updateDisplay("Wrong username");
        return;
      }

      // ---- Robust password extraction (supports List or Map storage) ----
      final dynamic record = userData[nameInput];

      String? storedPassword;
      if (record is List && record.isNotEmpty) {
        storedPassword = record[0]?.toString();
      } else if (record is Map) {
        storedPassword = record['password']?.toString();
      }

      if (storedPassword == null) {
        await analytics.logEvent(
          name: 'login_failed',
          parameters: {'reason': 'corrupt_user_record', 'screen': 'login'},
        );
        updateDisplay("Account data is invalid. Please re-register.");
        return;
      }

      if (storedPassword != passInput) {
        await analytics.logEvent(
          name: 'login_failed',
          parameters: {'reason': 'wrong_password', 'screen': 'login'},
        );
        updateDisplay("Wrong password");
        return;
      }
      // -----------------------------------------------------------------

      // Success
      await analytics.logEvent(
        name: 'login_success',
        parameters: {
          'screen': 'login',
          'username_length': nameInput.length,
        },
      );

      updateDisplay("Login successfully", isError: false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
    } catch (e) {
      debugPrint('Login exception: $e');
      await analytics.logEvent(
        name: 'login_failed',
        parameters: {'reason': 'exception', 'screen': 'login'},
      );
      updateDisplay("Login failed. Please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegistrationPage()),
    );
  }

  Future<void> _handleGoogleLogin() async {
    // Placeholder (kept from previous UI). Implement if/when you add Google Sign-In.
    updateDisplay("Google login not implemented.", isError: true);
  }

  @override
  void dispose() {
    accountName.dispose();
    accountPass.dispose();
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
                        _Dimens.gap24,

                        if (displayTxt.isNotEmpty) ...[
                          Text(
                            displayTxt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _displayColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          _Dimens.gap16,
                        ] else
                          _Dimens.gap16,

                        _Input(
                          controller: accountName,
                          hintText: 'Username',
                          obscureText: false,
                          textInputAction: TextInputAction.next,
                        ),
                        _Dimens.gap16,
                        _Input(
                          controller: accountPass,
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
