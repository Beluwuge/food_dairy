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
  static const profile = 'profile';
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
      final p = await SharedPreferenceHelper.getMap(StorageKeys.profile);
      _nameCtrl.text = (p['name'] ?? '').toString();
      _ageCtrl.text = (p['age'] ?? '').toString();
      _weightCtrl.text = (p['weightKg'] ?? '').toString();
      _heightCtrl.text = (p['heightCm'] ?? '').toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());

    if (name.isEmpty || age == null || w == null || h == null || age <= 0 || w <= 0 || h <= 0) {
      _err('Enter valid name, age, weight, height.');
      return;
    }

    final existing = await SharedPreferenceHelper.getMap(StorageKeys.profile);

    await SharedPreferenceHelper.saveMap(StorageKeys.profile, {
      ...existing,
      'name': name,
      'age': age,
      'weightKg': w,
      'heightCm': h,
    });

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _err(String m) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(m),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
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
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: AppColors.accentPrimary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Field(ctrl: _nameCtrl, label: 'Name', keyboardType: TextInputType.name),
            const SizedBox(height: 12),
            _Field(ctrl: _ageCtrl, label: 'Age', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _Field(ctrl: _weightCtrl, label: 'Weight (kg)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _Field(ctrl: _heightCtrl, label: 'Height (cm)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
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

  const _Field({required this.ctrl, required this.label, required this.keyboardType});

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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentPrimary)),
      ),
    );
  }
}