import 'package:flutter/material.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const accentPrimary = Color(0xFF0095F6);
  static const divider = Color(0xFF2A2A2E);
}

class StorageKeys {
  static const profile = 'profile'; // base key
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  bool _loading = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final username = await SharedPreferenceHelper.currentUsername();

      if (username == null || username.trim().isEmpty) {
        if (mounted) {
          _err('No logged-in user found. Please login again.');
        }
        return;
      }

      _username = username.trim();

      final profile = await SharedPreferenceHelper.getUserMap(
        StorageKeys.profile,
        _username!,
      );

      _nameCtrl.text = (profile['name'] ?? '').toString();
      _ageCtrl.text = (profile['age'] ?? '').toString();
      _weightCtrl.text = (profile['weightKg'] ?? '').toString();
      _heightCtrl.text = (profile['heightCm'] ?? '').toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    final weightKg = double.tryParse(_weightCtrl.text.trim());
    final heightCm = double.tryParse(_heightCtrl.text.trim());

    if (_username == null || _username!.trim().isEmpty) {
      _err('No logged-in user found. Please login again.');
      return;
    }

    if (name.isEmpty ||
        age == null ||
        weightKg == null ||
        heightCm == null ||
        age <= 0 ||
        weightKg <= 0 ||
        heightCm <= 0) {
      _err('Enter valid name, age, weight, and height.');
      return;
    }

    final existing = await SharedPreferenceHelper.getUserMap(
      StorageKeys.profile,
      _username!,
    );

    await SharedPreferenceHelper.saveUserMap(
      StorageKeys.profile,
      _username!,
      {
        ...existing,
        'name': name,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'activity': existing['activity'] ?? 'light',
      },
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _err(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Error',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.accentPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_username != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account: $_username',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (_username != null) const SizedBox(height: 12),
            _Field(
              ctrl: _nameCtrl,
              label: 'Name',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),
            _Field(
              ctrl: _ageCtrl,
              label: 'Age',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _Field(
              ctrl: _weightCtrl,
              label: 'Weight (kg)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            _Field(
              ctrl: _heightCtrl,
              label: 'Height (cm)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}