// lib/screens/first_run_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/models/user_model.dart';
import 'package:consistancy_tacker_v1/screens/home_screen.dart';

class FirstRunSetupScreen extends StatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  State<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends State<FirstRunSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Future<void> _saveUser() async {
    if (_formKey.currentState!.validate()) {
      final String userName = _nameController.text.trim();
      if (userName.isNotEmpty) {
        // Generate a simple unique ID for the user (e.g., timestamp)
        // In a real app, you might want a more robust ID generation strategy
        final int userId = DateTime.now().millisecondsSinceEpoch;
        final User newUser = User(
          id: userId,
          name: userName,
          createdAt: DateTime.now(),
        );

        await DatabaseService.instance.createUser(newUser);

        // After saving, navigate to the main dashboard.
        // For now, let's just pop the screen or show a success message.
        // The actual main dashboard will be implemented later.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome, $userName!')),
          );
          // Example: Navigate to a placeholder home screen
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
        }
      }
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
        title: const Text('Welcome to Consistency Tracker!'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                "Let's get started. What should we call you?",
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
              ElevatedButton(
                onPressed: _saveUser,
                child: const Text('Start Tracking!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
