// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/main.dart'; // Import themeNotifier, styleNotifier
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
      _monthlyCheatDays = user.monthlyCheatDays;
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
        Navigator.of(context).pop();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<User?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Could not load profile.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Customize how the application looks.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Theme Selector
                Text(
                  'Theme Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<ThemeMode>(
                          value: currentMode,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                            DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                          ],
                          onChanged: (value) {
                            if (value != null) _updateTheme(value);
                          },
                        ),
                      );
                    }
                  ),
                ),
                const SizedBox(height: 24),

                // Style Selector
                Text(
                  'App Style',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ValueListenableBuilder<VisualStyle>(
                    valueListenable: styleNotifier,
                    builder: (context, currentStyle, _) {
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<VisualStyle>(
                          value: currentStyle,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          items: const [
                            DropdownMenuItem(value: VisualStyle.minimalist, child: Text('Minimalist (Zinc)')),
                            DropdownMenuItem(value: VisualStyle.vibrant, child: Text('Vibrant (Colorful)')),
                          ],
                          onChanged: (value) {
                            if (value != null) _updateStyle(value);
                          },
                        ),
                      );
                    }
                  ),
                ),
                const SizedBox(height: 48),

                Text(
                  'Profile Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your identity and preferences.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Name Field
                Text(
                  'Display Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                  ),
                ),
                const SizedBox(height: 32),

                // Cheat Days Dropdown
                Text(
                  'Cheat Day Allowance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _monthlyCheatDays,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                      items: List.generate(6, (index) {
                        return DropdownMenuItem(
                          value: index,
                          child: Text(index == 1 ? '$index day per month' : '$index days per month'),
                        );
                      }),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _monthlyCheatDays = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Maximum number of cheat days allowed per month.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
                
                const SizedBox(height: 64),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Save Changes'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
