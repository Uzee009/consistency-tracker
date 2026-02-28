import 'package:flutter/material.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/screens/first_run_setup_screen.dart';
import 'package:consistency_tracker_v1/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

// Global notifiers for theme and style management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<VisualStyle> styleNotifier = ValueNotifier(VisualStyle.minimalist);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Initialize Window Manager
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(1050, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Load saved preferences
  final prefs = await SharedPreferences.getInstance();
  
  final themeIndex = prefs.getInt('theme_mode') ?? 0; // 0: system, 1: light, 2: dark
  themeNotifier.value = ThemeMode.values[themeIndex];

  final styleIndex = prefs.getInt('visual_style') ?? 0; // 0: minimalist, 1: vibrant
  styleNotifier.value = VisualStyle.values[styleIndex];

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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        return ValueListenableBuilder<VisualStyle>(
          valueListenable: styleNotifier,
          builder: (_, style, __) {
            final bool isDark = mode == ThemeMode.dark || 
                (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
            
            final primaryColor = StyleService.getPrimaryColor(style, isDark);

            return MaterialApp(
              title: 'Consistency Tracker',
              themeMode: mode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.grey,
                  primary: primaryColor,
                  surface: Colors.white,
                  onSurface: const Color(0xFF09090B),
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: Colors.white,
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF09090B),
                  elevation: 0,
                  centerTitle: true,
                  titleTextStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF09090B),
                    letterSpacing: 2,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF4F4F5),
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
                    borderSide: BorderSide(color: primaryColor, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintStyle: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: style == VisualStyle.vibrant ? Colors.white : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
                dividerTheme: const DividerThemeData(
                  thickness: 1,
                  color: Color(0xFFF4F4F5),
                  space: 1,
                ),
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.grey,
                  brightness: Brightness.dark,
                  primary: primaryColor,
                  surface: const Color(0xFF09090B),
                  onSurface: Colors.white,
                ),
                useMaterial3: true,
                scaffoldBackgroundColor: const Color(0xFF09090B),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF09090B),
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
                  fillColor: const Color(0xFF18181B),
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
                    borderSide: BorderSide(color: primaryColor, width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintStyle: const TextStyle(color: Color(0xFF27272A), fontSize: 14),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: isDark && style == VisualStyle.minimalist ? const Color(0xFF09090B) : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
                dividerTheme: const DividerThemeData(
                  thickness: 1,
                  color: Color(0xFF18181B),
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
      },
    );
  }
}
