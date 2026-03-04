import 'package:flutter/material.dart';
import 'services/shared_preference_helper.dart';
import 'main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> userData = {};
  String currentUser = "";
  String displayTxt = "Change password";

  final accountOldPass = TextEditingController();
  final accountNewPass = TextEditingController();
  final accountCfmPass = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final username = await SharedPreferenceHelper.currentUsername();
    if (username == null) return;

    final userDataMap = await SharedPreferenceHelper.getMap("userlist");

    setState(() {
      currentUser = username;
      userData = userDataMap;
    });
  }

  void updateDisplay(String txt) {
    setState(() {
      displayTxt = txt;
    });
  }

  Future<void> _updatePassword() async {
    String oldPass = accountOldPass.text.trim();
    String newPass = accountNewPass.text.trim();
    String confirmPass = accountCfmPass.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      updateDisplay("All fields are required.");
      return;
    }

    if (userData[currentUser][0] != oldPass) {
      updateDisplay("Incorrect current password.");
      return;
    }

    if (newPass != confirmPass) {
      updateDisplay("New password does not match confirmation.");
      return;
    }

    if (oldPass == newPass) {
      updateDisplay("New password must be different.");
      return;
    }

    // Update password
    userData[currentUser][0] = newPass;

    // Log out user
    userData[currentUser][1] = false;

    await SharedPreferenceHelper.saveMap("userlist", userData);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _logout() async {
    await SharedPreferenceHelper.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    userData.remove(currentUser);
    await SharedPreferenceHelper.saveMap("userlist", userData);

    // 🧹 Clear session
    await SharedPreferenceHelper.clearSession();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  Widget _secondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  Widget _dangerButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const Text("Account Settings"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Username: $currentUser",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayTxt,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _inputField(accountOldPass, "Current Password"),
            const SizedBox(height: 12),
            _inputField(accountNewPass, "New Password"),
            const SizedBox(height: 12),
            _inputField(accountCfmPass, "Confirm Password"),
            const SizedBox(height: 24),
            _primaryButton("Update Password", _updatePassword),
            const SizedBox(height: 12),
            _secondaryButton("Log Out", _logout),
            const SizedBox(height: 12),
            _dangerButton("Delete Account", _deleteAccount),
          ],
        ),
      ),
    );
  }
}