// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/services/pocketbase_service.dart';
import 'package:consistency_tracker_v1/screens/signup_screen.dart';

String _friendlyAuthError(Object e, {required bool isSignUp}) {
  final s = e.toString().toLowerCase();
  if (s.contains('failed to authenticate') ||
      s.contains('400') ||
      s.contains('401') ||
      s.contains('403') ||
      s.contains('invalid') ||
      s.contains('failed to create record')) {
    return isSignUp
        ? 'Could not create account. Email may already be in use, or the password is too weak.'
        : 'Wrong email or password.';
  }
  if (s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('connection') ||
      s.contains('timeout') ||
      s.contains('network')) {
    return 'Can\'t reach the server. Check your internet connection and try again.';
  }
  if (s.contains('500') ||
      s.contains('502') ||
      s.contains('503') ||
      s.contains('504') ||
      s.contains('server')) {
    return 'Server hiccup. Please try again in a moment.';
  }
  return isSignUp
      ? 'Sign-up failed. Please try again.'
      : 'Sign-in failed. Please try again.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = PocketBaseService.instance.serverUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Update server URL if changed
      if (_serverUrlController.text != PocketBaseService.instance.serverUrl) {
        await PocketBaseService.instance.setServerUrl(_serverUrlController.text);
      }

      // Attempt login
      await PocketBaseService.instance.login(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          debugPrint('Login error: $e');
          _errorMessage = _friendlyAuthError(e, isSignUp: false);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGN IN'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PocketBase Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to sync your tasks across devices.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFA1A1AA),
                  ),
                ),
                const SizedBox(height: 24),
                // Email field
                TextField(
                  controller: _emailController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    labelText: 'Email',
                    enabled: !_isLoading,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    labelText: 'Password',
                    enabled: !_isLoading,
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _isLoading ? null : _handleSignIn(),
                ),
                const SizedBox(height: 16),
                // Advanced section (server URL)
                GestureDetector(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: const Color(0xFFA1A1AA),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Advanced',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFA1A1AA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverUrlController,
                    decoration: InputDecoration(
                      hintText: 'https://consistancy.duckdns.org',
                      labelText: 'Server URL',
                      enabled: !_isLoading,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
                const SizedBox(height: 24),
                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Sign In button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignUpScreen(),
                              ),
                            );
                          },
                    child: const Text("Don't have an account? Create one"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
