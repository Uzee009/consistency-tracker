// lib/screens/first_run_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/models/user_model.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/screens/home_screen.dart';

class FirstRunSetupScreen extends StatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  State<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends State<FirstRunSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _monthlyCheatDays = 2; // Default value

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final String userName = _nameController.text.trim();
      if (userName.isNotEmpty) {
        final newUser = User(
          id: DateTime.now().millisecondsSinceEpoch,
          name: userName,
          createdAt: DateTime.now(),
          monthlyCheatDays: _monthlyCheatDays,
        );
        await DatabaseService.instance.createUser(newUser);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome!',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Let\'s get your consistency tracker set up.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Monthly Cheat Days'),
                  const Text('How many "cheat days" would you like per month? You can change this later.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _saveUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Get Started', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
