import 'package:flutter/material.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';
import 'package:food_dairy/main.dart';

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

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  // Keep your existing controllers
  final accountName = TextEditingController();
  final accountPass = TextEditingController();
  final cfmPass = TextEditingController();

  String displayTxt = "";
  bool _loading = false;

  void updateDisplay(String txt) {
    setState(() {
      displayTxt = txt;
    });
  }

  @override
  void dispose() {
    accountName.dispose();
    accountPass.dispose();
    cfmPass.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final nameInput = accountName.text.trim();
    final passInput = accountPass.text;
    final cfmInput = cfmPass.text;

    if (_loading) return;
    setState(() => _loading = true);

    try {
      // Read existing user list
      final Map<String, dynamic> userData =
      await SharedPreferenceHelper.getMap("userlist");

      // Keep your original validation logic (but corrected boolean operators)
      if (nameInput.isEmpty || passInput.isEmpty || cfmInput.isEmpty) {
        updateDisplay("Username or Password cannot be empty.");
        return;
      }

      if (userData.containsKey(nameInput)) {
        updateDisplay("Username used");
        return;
      }

      if (cfmInput != passInput) {
        updateDisplay("Password and confirm password does not match");
        return;
      }

      // Save new user
      userData[nameInput] = [passInput, false];
      await SharedPreferenceHelper.saveMap("userlist", userData);

      updateDisplay("Registered successfully");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text("Create Account"),
      ),
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
                        const _Header(),
                        _Dimens.gap48,

                        if (displayTxt.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayTxt,
                              style: TextStyle(
                                color: displayTxt == "Registered successfully"
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _Dimens.gap16,
                        ],

                        _Input(
                          controller: accountName,
                          hintText: 'Account Name',
                          icon: Icons.person,
                          obscureText: false,
                          textInputAction: TextInputAction.next,
                        ),
                        _Dimens.gap16,

                        _Input(
                          controller: accountPass,
                          hintText: 'Account Password',
                          icon: Icons.password,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                        ),
                        _Dimens.gap16,

                        _Input(
                          controller: cfmPass,
                          hintText: 'Confirm Password',
                          icon: Icons.confirmation_num_outlined,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleRegister(),
                        ),
                        _Dimens.gap8,

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleRegister,
                            style: _Styles.primaryButtonStyle(),
                            child: _loading
                                ? const _Spinner()
                                : const Text(
                              "Create New Account",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        _Dimens.gap16,

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _goToLogin,
                            style: _Styles.secondaryButtonStyle(),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  static ButtonStyle secondaryButtonStyle() {
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
    return Column(
      children: const [
        Icon(Icons.restaurant, size: 64, color: AppColors.textPrimary),
        SizedBox(height: 16),
        Text(
          'Sign Up',
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
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _Input({
    required this.controller,
    required this.hintText,
    required this.icon,
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
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
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
