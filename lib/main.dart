import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/screens/first_run_setup_screen.dart';
import 'package:consistency_tracker_v1/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Global notifier for theme management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
  themeNotifier.value = ThemeMode.values[themeIndex];

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
    final hasAnyUser = await DatabaseService.instance.hasUser();
    return !hasAnyUser;
  }

  @override
  Widget build(BuildContext context) {
    const Color zinc950 = Color(0xFF09090B);
    const Color zinc900 = Color(0xFF18181B);
    const Color zinc800 = Color(0xFF27272A);
    const Color zinc400 = Color(0xFFA1A1AA);
    const Color zinc100 = Color(0xFFF4F4F5);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return MaterialApp(
          title: 'Consistency Tracker',
          themeMode: mode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey,
              surface: Colors.white,
              onSurface: const Color(0xFF09090B),
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF09090B),
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF09090B),
                letterSpacing: 2,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: zinc100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Color(0xFF09090B), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintStyle: const TextStyle(color: zinc400, fontSize: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: zinc950,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            dividerTheme: const DividerThemeData(
              thickness: 1,
              color: zinc100,
              space: 1,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey,
              brightness: Brightness.dark,
              surface: zinc950,
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: zinc950,
            appBarTheme: const AppBarTheme(
              backgroundColor: zinc950,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: zinc900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintStyle: const TextStyle(color: zinc800, fontSize: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: zinc950,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            dividerTheme: const DividerThemeData(
              thickness: 1,
              color: zinc900,
              space: 1,
            ),
          ),
          debugShowCheckedModeBanner: false,
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
                if (snapshot.data == true) {
                  return const FirstRunSetupScreen();
                } else {
                  return const HomeScreen();
                }
              }
            },
          ),
        );
      },
    );
  }
}
