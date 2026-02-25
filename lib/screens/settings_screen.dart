// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';

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
    // Assuming the first user is the current user
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
      await DatabaseService.instance.updateUser(updatedUser); // Assumes updateUser exists
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved!')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: FutureBuilder<User?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Could not load user data.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Monthly Cheat Days'),
              const Text('How many "cheat days" you get per month.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              if (_monthlyCheatDays != null)
                DropdownButton<int>(
                  value: _monthlyCheatDays,
                  isExpanded: true,
                  items: List.generate(6, (index) {
                    return DropdownMenuItem(
                      value: index,
                      child: Text(index == 1 ? '$index day' : '$index days'),
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
            ],
          );
        },
      ),
    );
  }
}
