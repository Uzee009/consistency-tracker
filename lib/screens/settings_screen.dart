// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/services/audio_service.dart';
import 'package:consistency_tracker_v1/services/pocketbase_service.dart';
import 'package:consistency_tracker_v1/services/connectivity_service.dart';
import 'package:consistency_tracker_v1/screens/login_screen.dart';
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

                  const SizedBox(height: 40),

                  _buildSectionHeader('SOUND & FEEDBACK', 'Configure notification sounds and haptics.'),
                  _buildCard(context, [
                    ValueListenableBuilder<bool>(
                      valueListenable: AudioService.instance.isEnabled,
                      builder: (context, enabled, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound Effects', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Play sounds during Pomodoro sessions', style: TextStyle(fontSize: 12)),
                        value: enabled,
                        onChanged: (v) => AudioService.instance.toggleEnabled(v),
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Sound Pack'),
                    ValueListenableBuilder<SoundPack>(
                      valueListenable: AudioService.instance.currentPack,
                      builder: (context, pack, _) => _buildDropdown<SoundPack>(
                        value: pack,
                        items: const [
                          DropdownMenuItem(value: SoundPack.zen, child: Text('Zen (Calm)')),
                          DropdownMenuItem(value: SoundPack.minimal, child: Text('Minimalist (Digital)')),
                          DropdownMenuItem(value: SoundPack.retro, child: Text('Retro (8-bit)')),
                        ],
                        onChanged: (v) { if (v != null) AudioService.instance.setPack(v); },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Preview Sounds'),
                    Row(
                      children: [
                        _buildPreviewChip('Timer End', AudioType.timerEnd),
                        const SizedBox(width: 12),
                        _buildPreviewChip('Goal Reached', AudioType.goalReached),
                      ],
                    ),
                    ]),

                  const SizedBox(height: 40),

                  _buildSectionHeader('SYNC & CONNECTIVITY', 'Manage cloud synchronization across devices.'),
                  _buildCard(context, [
                    ValueListenableBuilder<bool>(
                      valueListenable: PocketBaseService.instance.authState,
                      builder: (context, isAuthenticated, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Account Status'),
                            const SizedBox(height: 8),
                            if (!isAuthenticated)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Not signed in',
                                    style: TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                                    ),
                                    child: const Text('Sign In'),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Signed in as ${PocketBaseService.instance.userEmail ?? 'unknown'}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => PocketBaseService.instance.logout(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Connection Status'),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService.instance.isOnline,
                      builder: (context, isOnline, _) {
                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOnline ? Colors.green : Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 14,
                                color: isOnline ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _buildPreviewChip(String label, AudioType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => AudioService.instance.playSound(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
