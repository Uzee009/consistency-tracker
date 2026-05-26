import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/services/pocketbase_service.dart';
import 'package:consistency_tracker_v1/services/connectivity_service.dart';
import 'package:consistency_tracker_v1/screens/first_run_setup_screen.dart';
import 'package:consistency_tracker_v1/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:consistency_tracker_v1/services/audio_service.dart';
import 'dart:async';
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
      size: Size(1400, 900),
      minimumSize: Size(1250, 850), // Increased from 700 to accommodate 2x 400px panels
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

  // SEED DATA ONLY IN DEV MODE, and ONLY on a fresh (empty) dev DB.
  // Re-seeding on every launch would wipe + regenerate task sids and break sync.
  // To intentionally reseed during dev, delete the dev DB file.
  if (const String.fromEnvironment('DATABASE_NAME') == 'consistency_tracker_dev.db'
      && !await DatabaseService.instance.hasUser()) {
    debugPrint('DatabaseService: Seeding development data (empty dev DB)...');
    await DatabaseService.instance.seedData();
  }

  await AudioService.instance.initialize();

  // Initialize PocketBase service (handles auth token restoration)
  await PocketBaseService.instance.init();

  // Initialize connectivity service (checks online status + subscribes to changes)
  await ConnectivityService.instance.init();

  unawaited(PocketBaseService.instance.tryDevAutoLogin());

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _isFirstRun;
  late ThemeMode _currentThemeMode;
  late VisualStyle _currentVisualStyle;
  late bool _isDark;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeThemeAndStyle();
    themeNotifier.addListener(_updateThemeAndStyle);
    styleNotifier.addListener(_updateThemeAndStyle);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_updateThemeAndStyle);
    styleNotifier.removeListener(_updateThemeAndStyle);
    super.dispose();
  }

  Future<void> _initializeThemeAndStyle() async {
    // Ensure WidgetsFlutterBinding is initialized (already in main but good practice)
    WidgetsFlutterBinding.ensureInitialized();
    // Re-check and set notifiers if main didn't
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_mode') ?? 0;
    themeNotifier.value = ThemeMode.values[themeIndex];
    final styleIndex = prefs.getInt('visual_style') ?? 0;
    styleNotifier.value = VisualStyle.values[styleIndex];

    // Initialize state variables *after* notifiers are guaranteed set
    _currentThemeMode = themeNotifier.value;
    _currentVisualStyle = styleNotifier.value;

    // Calculate initial _isDark based on system brightness if ThemeMode.system
    _isDark = _currentThemeMode == ThemeMode.dark ||
              (_currentThemeMode == ThemeMode.system &&
               WidgetsBinding.instance.window.platformBrightness == Brightness.dark);

    // Also set _isFirstRun here as it depends on DatabaseService which needs init
    _isFirstRun = _checkFirstRun();
    await _isFirstRun; // Wait for first run check to complete
  }

  void _updateThemeAndStyle() {
    if (mounted) {
      setState(() {
        _currentThemeMode = themeNotifier.value;
        _currentVisualStyle = styleNotifier.value;
        // Recalculate _isDark based on the new values
        _isDark = _currentThemeMode == ThemeMode.dark ||
                  (_currentThemeMode == ThemeMode.system &&
                   WidgetsBinding.instance.window.platformBrightness == Brightness.dark);
      });
    }
  }

  Future<bool> _checkFirstRun() async {
    // This part runs after global initializations
    final hasAnyUser = await DatabaseService.instance.hasUser();
    return !hasAnyUser;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a simple loading screen or splash screen while theme is initializing
          return ColoredBox(
            color: (themeNotifier.value == ThemeMode.dark ||
                    (themeNotifier.value == ThemeMode.system &&
                     MediaQuery.platformBrightnessOf(context) == Brightness.dark))
                   ? const Color(0xFF09090B) // Dark background
                   : Colors.white, // Light background
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Error initializing app: ${snapshot.error}')),
            ),
          );
        }

        // Only build MaterialApp once initialization is complete
        final primaryColor = StyleService.getPrimaryColor(_currentVisualStyle, _isDark);

        return MaterialApp(
          title: 'Consistency Tracker',
          themeMode: _currentThemeMode,
          theme: ThemeData(
            textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
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
              titleTextStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF09090B),
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
                foregroundColor: _currentVisualStyle == VisualStyle.vibrant ? Colors.white : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
            dividerTheme: const DividerThemeData(
              thickness: 1,
              color: Color(0xFFF4F4F5),
              space: 1,
            ),
          ),
          darkTheme: ThemeData(
            textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey,
              brightness: Brightness.dark,
              primary: primaryColor,
              surface: const Color(0xFF09090B),
              onSurface: Colors.white,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF09090B),
            appBarTheme: AppBarTheme(
              backgroundColor: const Color(0xFF09090B),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: const TextStyle(
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
                foregroundColor: _isDark && _currentVisualStyle == VisualStyle.minimalist ? const Color(0xFF09090B) : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
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
                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: const Center(
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
