// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<User?> _userFuture;
  final _nameController = TextEditingController();
  int? _monthlyCheatDays;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  Future<User?> _loadUserData() async {
    final users = await DatabaseService.instance.getAllUsers();
    if (users.isNotEmpty) {
      final user = users.first;
      _nameController.text = user.name;
      _monthlyCheatDays = user.monthlyCheatDays.clamp(0, 5);
      return user;
    }
    return null;
  }

  Future<void> _saveSettings() async {
    final user = await _userFuture;
    if (user != null && _monthlyCheatDays != null) {
      final updatedUser = User(
        id: user.id,
        name: _nameController.text,
        createdAt: user.createdAt,
        monthlyCheatDays: _monthlyCheatDays!,
      );
      await DatabaseService.instance.updateUser(updatedUser);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.')),
        );
        if (!widget.isEmbedded) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  Future<void> _updateStyle(VisualStyle style) async {
    styleNotifier.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('visual_style', style.index);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<User?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Could not load profile.'));
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('PROFILE', 'Manage your identity and daily allowance.'),
                  _buildCard(context, [
                    _buildLabel('Display Name'),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Your name', isDense: true),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Cheat Day Allowance'),
                    _buildDropdown<int>(
                      value: _monthlyCheatDays,
                      items: List.generate(6, (i) => DropdownMenuItem(value: i, child: Text(i == 1 ? '1 day / mo' : '$i days / mo'))),
                      onChanged: (v) => setState(() => _monthlyCheatDays = v),
                    ),
                  ]),

                  const SizedBox(height: 40),

                  _buildSectionHeader('APPEARANCE', 'Customize the visual personality of the app.'),
                  _buildCard(context, [
                    _buildLabel('Theme Mode'),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, mode, _) => _buildDropdown<ThemeMode>(
                        value: mode,
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                        ],
                        onChanged: (v) { if (v != null) _updateTheme(v); },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('App Style'),
                    ValueListenableBuilder<VisualStyle>(
                      valueListenable: styleNotifier,
                      builder: (context, style, _) => _buildDropdown<VisualStyle>(
                        value: style,
                        items: const [
                          DropdownMenuItem(value: VisualStyle.minimalist, child: Text('Minimalist (Zinc)')),
                          DropdownMenuItem(value: VisualStyle.vibrant, child: Text('Vibrant (Colorful)')),
                        ],
                        onChanged: (v) { if (v != null) _updateStyle(v); },
                      ),
                    ),
                  ]),

                  const SizedBox(height: 48),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!widget.isEmbedded)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('CANCEL'),
                        ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text('SAVE CHANGES'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (widget.isEmbedded) return Scaffold(backgroundColor: Colors.transparent, body: content);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: content,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Colors.grey)),
    );
  }

  Widget _buildDropdown<T>({required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
