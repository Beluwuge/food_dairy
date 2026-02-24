import 'dart:math';
import 'package:flutter/material.dart';
import 'package:food_dairy/services/shared_preference_helper.dart';

class AppColors {
  static const bgPrimary = Color(0xFF000000);
  static const bgSecondary = Color(0xFF121212);
  static const bgElevated = Color(0xFF1C1C1E);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA8A8A8);
  static const accentPrimary = Color(0xFF0095F6);
  static const divider = Color(0xFF2A2A2E);
}

class StorageKeys {
  static const profile = 'profile';
  static const waterLog = 'water_log'; // stores {"YYYY-MM-DD": intMl}
}

class _Dimens {
  static const pagePadding = EdgeInsets.all(24);
  static const fieldPadding = EdgeInsets.all(16);
  static const cardPadding = EdgeInsets.all(16);
  static const buttonVPadding = EdgeInsets.symmetric(vertical: 16);
  static const r8 = 8.0;

  static const gap8 = SizedBox(height: 8);
  static const gap12 = SizedBox(height: 12);
  static const gap16 = SizedBox(height: 16);
  static const gap24 = SizedBox(height: 24);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Profile inputs
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightKgCtrl = TextEditingController();
  final _heightCmCtrl = TextEditingController();

  // Water controls
  int _todayWaterMl = 0;
  int _quickAddMl = 250;

  bool _loading = true;

  // Derived outputs
  double? _bmi;
  String _bmiLabel = '-';
  int? _calories; // simple maintenance estimate

  String get _todayKey {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  void initState() {
    super.initState();
    _loadStored();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightKgCtrl.dispose();
    _heightCmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStored() async {
    try {
      final profile = await SharedPreferenceHelper.getMap(StorageKeys.profile);
      final water = await SharedPreferenceHelper.getMap(StorageKeys.waterLog);

      _nameCtrl.text = (profile['name'] ?? '').toString();
      _ageCtrl.text = (profile['age'] ?? '').toString();
      _weightKgCtrl.text = (profile['weightKg'] ?? '').toString();
      _heightCmCtrl.text = (profile['heightCm'] ?? '').toString();

      final today = water[_todayKey];
      _todayWaterMl = (today is num) ? today.toInt() : 0;

      _recompute();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recompute() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final w = double.tryParse(_weightKgCtrl.text.trim());
    final hCm = double.tryParse(_heightCmCtrl.text.trim());

    // BMI
    if (w != null && hCm != null && w > 0 && hCm > 0) {
      final hM = hCm / 100.0;
      _bmi = w / (hM * hM);

      final v = _bmi!;
      if (v < 18.5) _bmiLabel = 'Underweight';
      else if (v < 25) _bmiLabel = 'Normal';
      else if (v < 30) _bmiLabel = 'Overweight';
      else _bmiLabel = 'Obese';
    } else {
      _bmi = null;
      _bmiLabel = '-';
    }

    // Calories (simple maintenance estimate)
    // Using Mifflin-St Jeor requires sex; you didn't request it.
    // So we use a simple heuristic: maintenance ≈ 24 * weightKg * 1.3 (light activity).
    if (w != null && w > 0) {
      final est = (24.0 * w * 1.3).round();
      _calories = est;
    } else {
      _calories = null;
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text.trim());
    final w = double.tryParse(_weightKgCtrl.text.trim());
    final h = double.tryParse(_heightCmCtrl.text.trim());

    if (name.isEmpty || age == null || w == null || h == null || age <= 0 || w <= 0 || h <= 0) {
      _showError('Please enter valid name, age, weight (kg) and height (cm).');
      return;
    }

    await SharedPreferenceHelper.saveMap(StorageKeys.profile, {
      'name': name,
      'age': age,
      'weightKg': w,
      'heightCm': h,
    });

    if (!mounted) return;
    setState(() {
      _recompute();
    });

    _toast('Profile saved');
  }

  Future<void> _saveWater() async {
    final water = await SharedPreferenceHelper.getMap(StorageKeys.waterLog);
    water[_todayKey] = _todayWaterMl;
    await SharedPreferenceHelper.saveMap(StorageKeys.waterLog, water);
  }

  Future<void> _addWater(int ml) async {
    if (ml <= 0) return;
    setState(() {
      _todayWaterMl = max(0, _todayWaterMl + ml);
    });
    await _saveWater();
  }

  Future<void> _resetWater() async {
    setState(() => _todayWaterMl = 0);
    await _saveWater();
  }

  int _recommendedWaterMl() {
    final w = double.tryParse(_weightKgCtrl.text.trim());
    if (w == null || w <= 0) return 2000; // fallback
    // Simple rule: 35 ml per kg
    return (35 * w).round();
  }

  double _waterProgress() {
    final rec = _recommendedWaterMl();
    if (rec <= 0) return 0;
    return (_todayWaterMl / rec).clamp(0.0, 1.0);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.bgElevated,
      ),
    );
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
            ),
          ),
        ),
      );
    }

    final recWater = _recommendedWaterMl();
    final progress = _waterProgress();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: _Dimens.pagePadding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileCard(
                nameCtrl: _nameCtrl,
                ageCtrl: _ageCtrl,
                weightCtrl: _weightKgCtrl,
                heightCtrl: _heightCmCtrl,
                onChanged: () {
                  setState(_recompute);
                },
                onSave: _saveProfile,
              ),
              _Dimens.gap16,

              _InfoCard(
                title: 'BMI Calculator',
                subtitle: 'Based on weight (kg) and height (cm)',
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'BMI',
                        value: _bmi == null ? '-' : _bmi!.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Category',
                        value: _bmiLabel,
                      ),
                    ),
                  ],
                ),
              ),
              _Dimens.gap16,

              _InfoCard(
                title: 'Calories Calculator',
                subtitle: 'Simple daily maintenance estimate (no activity/sex input)',
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Estimated kcal/day',
                        value: _calories?.toString() ?? '-',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        label: 'Assumption',
                        value: 'Light activity',
                      ),
                    ),
                  ],
                ),
              ),
              _Dimens.gap16,

              _InfoCard(
                title: 'Daily Water Intake',
                subtitle: 'Today: $_todayKey • Recommended: $recWater ml',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_Dimens.r8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentPrimary),
                      ),
                    ),
                    _Dimens.gap12,
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'Today (ml)',
                            value: '$_todayWaterMl',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricTile(
                            label: 'Remaining (ml)',
                            value: '${max(0, recWater - _todayWaterMl)}',
                          ),
                        ),
                      ],
                    ),
                    _Dimens.gap12,
                    Row(
                      children: [
                        Expanded(
                          child: _Dropdown<int>(
                            value: _quickAddMl,
                            items: const [150, 250, 350, 500],
                            itemLabel: (v) => '$v ml',
                            onChanged: (v) => setState(() => _quickAddMl = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _addWater(_quickAddMl),
                            style: _Styles.primaryButtonStyle(),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _Dimens.gap12,
                    OutlinedButton(
                      onPressed: _resetWater,
                      style: _Styles.secondaryButtonStyle(),
                      child: const Text(
                        'Reset today',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _ProfileCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final VoidCallback onChanged;
  final Future<void> Function() onSave;

  const _ProfileCard({
    required this.nameCtrl,
    required this.ageCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Profile',
      subtitle: 'Enter your details for better estimates',
      child: Column(
        children: [
          _Input(
            controller: nameCtrl,
            hintText: 'Name',
            icon: Icons.person,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          _Dimens.gap16,
          _Input(
            controller: ageCtrl,
            hintText: 'Age',
            icon: Icons.cake,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          _Dimens.gap16,
          _Input(
            controller: weightCtrl,
            hintText: 'Weight (kg)',
            icon: Icons.monitor_weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          _Dimens.gap16,
          _Input(
            controller: heightCtrl,
            hintText: 'Height (cm)',
            icon: Icons.height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: (_) => onChanged(),
          ),
          _Dimens.gap16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              style: _Styles.primaryButtonStyle(),
              child: const Text(
                'Save Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _Dimens.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(_Dimens.r8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          _Dimens.gap8,
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.2,
            ),
          ),
          _Dimens.gap16,
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(_Dimens.r8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          _Dimens.gap8,
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;

  const _Input({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    required this.textInputAction,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: true,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.bgSecondary,
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

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(_Dimens.r8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: AppColors.bgElevated,
          iconEnabledColor: AppColors.textSecondary,
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
              value: v,
              child: Text(
                itemLabel(v),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}