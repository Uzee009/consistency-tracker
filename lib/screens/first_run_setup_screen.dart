import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/models/user_model.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/screens/home_screen.dart';
import 'package:consistency_tracker_v1/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirstRunSetupScreen extends StatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  State<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends State<FirstRunSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  VisualStyle _selectedStyle = VisualStyle.minimalist;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _completeSetup() async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch,
        name: name,
        createdAt: DateTime.now(),
        monthlyCheatDays: 2,
      );
      await DatabaseService.instance.createUser(newUser);

      // Save style preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('visual_style', _selectedStyle.index);
      styleNotifier.value = _selectedStyle;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  Widget _buildStyleOption(VisualStyle style, String title, IconData icon) {
    final isSelected = _selectedStyle == style;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStyle = style),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.transparent : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected 
                    ? (isDark ? Colors.black : Colors.white)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isSelected 
                      ? (isDark ? Colors.black : Colors.white)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'CONSISTENCY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 64),
              Text(
                'Build your discipline.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 48),
              
              Text(
                'WHAT IS YOUR NAME?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'John Doe',
                  fillColor: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 40),

              Text(
                'CHOOSE YOUR VIBE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStyleOption(VisualStyle.minimalist, 'MINIMALIST', Icons.filter_vintage_outlined),
                  const SizedBox(width: 12),
                  _buildStyleOption(VisualStyle.vibrant, 'VIBRANT', Icons.auto_awesome_outlined),
                ],
              ),
              const SizedBox(height: 48),
              
              ElevatedButton(
                onPressed: _completeSetup,
                child: const Text(
                  'Start Tracking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              Text(
                'Minimalist habit tracking for the focused mind.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
