// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/services/audio_service.dart';
import 'package:consistency_tracker_v1/services/pocketbase_service.dart';
import 'package:consistency_tracker_v1/services/connectivity_service.dart';
import 'package:consistency_tracker_v1/services/sync_service.dart';
import 'package:consistency_tracker_v1/screens/login_screen.dart';
import 'package:consistency_tracker_v1/screens/signup_screen.dart';
import 'package:consistency_tracker_v1/main.dart';
import 'package:consistency_tracker_v1/widgets/sync_status.dart';
import 'package:consistency_tracker_v1/services/update_service.dart';
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
  String? _currentVersion;
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final version = await UpdateService.instance.getCurrentVersion();
      if (mounted) {
        setState(() => _currentVersion = version);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentVersion = 'Error');
      }
    }
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
    await prefs.setInt(DatabaseService.prefixedKey('theme_mode'), mode.index);
  }

  Future<void> _updateStyle(VisualStyle style) async {
    styleNotifier.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        DatabaseService.prefixedKey('visual_style'), style.index);
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
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return const Center(child: Text('Could not load profile.'));
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      'PROFILE', 'Manage your identity and daily allowance.'),
                  _buildCard(context, [
                    _buildLabel('Display Name'),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                          hintText: 'Your name', isDense: true),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Cheat Day Allowance'),
                    _buildDropdown<int>(
                      value: _monthlyCheatDays,
                      items: List.generate(
                          6,
                          (i) => DropdownMenuItem(
                              value: i,
                              child: Text(
                                  i == 1 ? '1 day / mo' : '$i days / mo'))),
                      onChanged: (v) => setState(() => _monthlyCheatDays = v),
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildSectionHeader('APPEARANCE',
                      'Customize the visual personality of the app.'),
                  _buildCard(context, [
                    _buildLabel('Theme Mode'),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, mode, _) => _buildDropdown<ThemeMode>(
                        value: mode,
                        items: const [
                          DropdownMenuItem(
                              value: ThemeMode.system,
                              child: Text('System Default')),
                          DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text('Light Mode')),
                          DropdownMenuItem(
                              value: ThemeMode.dark, child: Text('Dark Mode')),
                        ],
                        onChanged: (v) {
                          if (v != null) _updateTheme(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('App Style'),
                    ValueListenableBuilder<VisualStyle>(
                      valueListenable: styleNotifier,
                      builder: (context, style, _) =>
                          _buildDropdown<VisualStyle>(
                        value: style,
                        items: const [
                          DropdownMenuItem(
                              value: VisualStyle.minimalist,
                              child: Text('Minimalist (Zinc)')),
                          DropdownMenuItem(
                              value: VisualStyle.vibrant,
                              child: Text('Vibrant (Colorful)')),
                        ],
                        onChanged: (v) {
                          if (v != null) _updateStyle(v);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildSectionHeader('SOUND & FEEDBACK',
                      'Configure notification sounds and haptics.'),
                  _buildCard(context, [
                    ValueListenableBuilder<bool>(
                      valueListenable: AudioService.instance.isEnabled,
                      builder: (context, enabled, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Sound Effects',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Play sounds during Pomodoro sessions',
                            style: TextStyle(fontSize: 12)),
                        value: enabled,
                        onChanged: (v) =>
                            AudioService.instance.toggleEnabled(v),
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
                          DropdownMenuItem(
                              value: SoundPack.zen, child: Text('Zen (Calm)')),
                          DropdownMenuItem(
                              value: SoundPack.minimal,
                              child: Text('Minimalist (Digital)')),
                          DropdownMenuItem(
                              value: SoundPack.retro,
                              child: Text('Retro (8-bit)')),
                        ],
                        onChanged: (v) {
                          if (v != null) AudioService.instance.setPack(v);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Preview Sounds'),
                    Row(
                      children: [
                        _buildPreviewChip('Timer End', AudioType.timerEnd),
                        const SizedBox(width: 12),
                        _buildPreviewChip(
                            'Goal Reached', AudioType.goalReached),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildSectionHeader('SYNC & CONNECTIVITY',
                      'Manage cloud synchronization across devices.'),
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
                                  const Row(
                                    children: [
                                      Icon(Icons.sync_disabled,
                                          size: 16, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text(
                                        'Sync off — not signed in',
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const LoginScreen()),
                                        ),
                                        child: const Text('Sign In'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const SignUpScreen()),
                                        ),
                                        child: const Text('Create Account'),
                                      ),
                                    ],
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
                                    onPressed: () =>
                                        PocketBaseService.instance.logout(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.red.withValues(alpha: 0.1),
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
                    _buildLabel('Sync Status'),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService.instance.isOnline,
                      builder: (context, isOnline, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: PocketBaseService.instance.authState,
                          builder: (context, isAuthed, _) {
                            final readiness = computeSyncReadiness(
                                serverReachable: isOnline, authed: isAuthed);
                            final color = syncStatusColor(readiness);
                            final tooltip =
                                syncStatusTooltip(readiness, authed: isAuthed);

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tooltip,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: color,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildLabel('Synchronization'),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: SyncService.instance.isSyncing,
                      builder: (context, isSyncing, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: PocketBaseService.instance.authState,
                          builder: (context, isAuthed, __) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: (isSyncing || !isAuthed)
                                      ? null
                                      : _handleSyncNow,
                                  icon: isSyncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.sync, size: 18),
                                  label:
                                      Text(isSyncing ? 'Syncing…' : 'Sync Now'),
                                ),
                                if (!isAuthed) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Sign in or create an account to enable sync.',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ] else if (SyncService.instance.lastSyncedAt !=
                                    null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Last synced: ${_formatLastSynced(SyncService.instance.lastSyncedAt!)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildSectionHeader('UPDATES', 'Keep the app up to date.'),
                  _buildCard(context, [
                    // Current Version display
                    _buildLabel('Current Version'),
                    Text(
                      _currentVersion ?? '…',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // Update Status (ValueListenableBuilder)
                    _buildLabel('Status'),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<UpdateInfo?>(
                      valueListenable: UpdateService.instance.available,
                      builder: (context, available, _) {
                        if (available != null) {
                          return Text(
                            'Update available: v${available.version}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700] ?? Colors.orange,
                            ),
                          );
                        } else {
                          return Text(
                            'You\'re on the latest version.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Check for Updates Button
                    ElevatedButton.icon(
                      onPressed: _checkingUpdate ? null : _handleCheckForUpdate,
                      icon: _checkingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update, size: 18),
                      label: Text(
                          _checkingUpdate ? 'Checking…' : 'Check for Updates'),
                    ),
                    const SizedBox(height: 12),

                    // Download Button Area (now reactive)
                    ValueListenableBuilder<UpdateInfo?>(
                      valueListenable: UpdateService.instance.available,
                      builder: (context, available, _) {
                        if (available == null) return const SizedBox.shrink();

                        return ValueListenableBuilder<UpdateProgress>(
                          valueListenable: UpdateService.instance.progress,
                          builder: (context, progress, _) {
                            if (progress.stage == UpdateStage.idle) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => UpdateService.instance
                                        .downloadAndApply(),
                                    icon:
                                        const Icon(Icons.restart_alt, size: 18),
                                    label: const Text('Update & Restart'),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: () =>
                                        UpdateService.instance.openDownload(),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Download manually',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              );
                            } else if (progress.stage == UpdateStage.error) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    progress.message ?? 'Update failed',
                                    style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => UpdateService.instance
                                            .downloadAndApply(),
                                        child: const Text('Try again'),
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton(
                                        onPressed: () => UpdateService.instance
                                            .openDownload(),
                                        child: const Text('Download manually',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              // Downloading, Verifying, Applying, Restarting
                              String stageLabel = '';
                              switch (progress.stage) {
                                case UpdateStage.downloading:
                                  final pct = (progress.pct ?? 0) * 100;
                                  stageLabel =
                                      'Downloading update… ${pct.round()}%';
                                  break;
                                case UpdateStage.verifying:
                                  stageLabel = 'Verifying update…';
                                  break;
                                case UpdateStage.applying:
                                  stageLabel = 'Installing update…';
                                  break;
                                case UpdateStage.restarting:
                                  stageLabel = 'Restarting…';
                                  break;
                                default:
                                  break;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stageLabel,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress.pct,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
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

    if (widget.isEmbedded)
      return Scaffold(backgroundColor: Colors.transparent, body: content);

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
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
        border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
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
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.grey)),
    );
  }

  Widget _buildDropdown<T>(
      {required T? value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface),
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                size: 12, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSyncNow() async {
    // Capture the messenger before the await to avoid using context across async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final result = await SyncService.instance.sync();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(result.summary)),
    );
  }

  Future<void> _handleCheckForUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checkingUpdate = true);
    try {
      final result = await UpdateService.instance.checkForUpdate(manual: true);
      if (!mounted) return;

      String message;
      switch (result) {
        case UpdateCheckResult.updateAvailable:
          final info = UpdateService.instance.available.value;
          message = info != null
              ? 'Update available: v${info.version}'
              : 'Update available.';
          break;
        case UpdateCheckResult.upToDate:
          message = 'You\'re on the latest version.';
          break;
        case UpdateCheckResult.offline:
          message = 'You\'re offline — can\'t check for updates.';
          break;
        case UpdateCheckResult.error:
          message = 'Couldn\'t check for updates. Try again later.';
          break;
      }

      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  String _formatLastSynced(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
