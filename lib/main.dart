import 'package:flutter/material.dart';
import 'package:consistancy_tacker_v1/services/database_service.dart';
import 'package:consistancy_tacker_v1/screens/first_run_setup_screen.dart';
import 'package:consistancy_tacker_v1/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io'; // For Platform check

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _isFirstRun;

  @override
  void initState() {
    super.initState();
    _isFirstRun = _checkFirstRun();
  }

  Future<bool> _checkFirstRun() async {
    // Check if any user exists in the database.
    final hasAnyUser = await DatabaseService.instance.hasUser();
    return !hasAnyUser; // If no user exists, it's a first run
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consistency Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: FutureBuilder<bool>(
        future: _isFirstRun,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          } else {
            // If it's the first run, show the setup screen.
            // Otherwise, show the home screen.
            if (snapshot.data == true) {
              return const FirstRunSetupScreen();
            } else {
              return const HomeScreen();
            }
          }
        },
      ),
    );
  }
}