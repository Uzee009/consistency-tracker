import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:consistency_tracker_v1/services/database_service.dart';
import 'package:consistency_tracker_v1/services/style_service.dart';
import 'package:consistency_tracker_v1/services/pocketbase_service.dart';
import 'package:consistency_tracker_v1/services/connectivity_service.dart';
import 'package:consistency_tracker_v1/services/account_registry.dart';
import 'package:consistency_tracker_v1/services/device_id_service.dart';
import 'package:consistency_tracker_v1/screens/first_run_setup_screen.dart';
import 'package:consistency_tracker_v1/screens/home_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:consistency_tracker_v1/services/audio_service.dart';
import 'package:consistency_tracker_v1/services/sync_service.dart';
import 'package:consistency_tracker_v1/services/update_service.dart';
import 'package:consistency_tracker_v1/services/motion_settings_service.dart';
import 'package:consistency_tracker_v1/utils/idle_detector.dart';
import 'package:consistency_tracker_v1/widgets/motion/ambient_dim.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

// Global notifiers for theme and style management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<VisualStyle> styleNotifier =
    ValueNotifier(VisualStyle.minimalist);
final ValueNotifier<MotionSettings> motionNotifier = ValueNotifier(const MotionSettings());
final ValueNotifier<bool> windowFocusedNotifier = ValueNotifier(true);
final ValueNotifier<bool> userActiveNotifier = ValueNotifier(true);

void _cleanupOldUpdate() {
  try {
    final exe = Platform.resolvedExecutable;
    String installParent;

    if (Platform.isLinux || Platform.isWindows) {
      installParent = p.dirname(p.dirname(exe));
    } else if (Platform.isMacOS) {
      var current = exe;
      String? appPath;
      while (current != p.dirname(current)) {
        if (p.basename(current).endsWith('.app')) {
          appPath = current;
          break;
        }
        current = p.dirname(current);
      }
      if (appPath == null) return;
      installParent = p.dirname(appPath);
    } else {
      return;
    }

    final cleanupFile = File(p.join(installParent, '.ct_update_cleanup'));
    if (cleanupFile.existsSync()) {
      final lines = cleanupFile.readAsLinesSync();
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final dir = Directory(line.trim());
          if (dir.existsSync()) {
            dir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
      cleanupFile.deleteSync();
    }
  } catch (_) {
    // Ignore entirely
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cleanupOldUpdate();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Initialize Window Manager
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1400, 900),
      minimumSize:
          Size(1250, 850), // Increased from 700 to accommodate 2x 400px panels
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

  final themeIndex = prefs.getInt(DatabaseService.prefixedKey('theme_mode')) ??
      0; // 0: system, 1: light, 2: dark
  themeNotifier.value = ThemeMode.values[themeIndex];

  final styleIndex =
      prefs.getInt(DatabaseService.prefixedKey('visual_style')) ??
          0; // 0: minimalist, 1: vibrant
  styleNotifier.value = VisualStyle.values[styleIndex];

  motionNotifier.value = await MotionSettingsService.load();

  IdleDetector.instance.initialize(userActiveNotifier);

  await AudioService.instance.initialize();

  // Initialize PocketBase service (handles auth token restoration)
  await PocketBaseService.instance.init();

  await DeviceIdService.instance.init();

  // Step 15B: account isolation bootstrap. Order matters:
  //   1. migrate legacy single-DB file (if any) into accounts/<userId>.db
  //   2. evict idle accounts (>30 days), deleting their .db files
  //   3. open the active account's DB
  final activeUserId = PocketBaseService.instance.client.authStore.record?.id;
  await DatabaseService.instance.migrateLegacyDb(activeUserId: activeUserId);
  final evicted = await AccountRegistry.instance.evictIdle(
    ttl: const Duration(days: 30),
    activeUserId: activeUserId,
  );
  await DatabaseService.instance.deleteAccountDbs(evicted);
  await DatabaseService.instance.switchTo(activeUserId);

  // Initialize connectivity service (checks online status + subscribes to changes)
  await ConnectivityService.instance.init();

  unawaited(UpdateService.instance.checkForUpdate());

  unawaited(PocketBaseService.instance.tryDevAutoLogin());

  SyncService.instance.startAuto();

  // Step 15B: single switch chokepoint. Fires on sign-in AND sign-out.
  PocketBaseService.instance.authState.addListener(() async {
    final newUserId = PocketBaseService.instance.client.authStore.record?.id;
    final signedIn = PocketBaseService.instance.isAuthenticated;
    await SyncService.instance.pauseForSwitch();
    if (signedIn) {
      // sign-IN: swap to <userId>.db, then resume sync.
      await DatabaseService.instance.switchTo(newUserId);
      SyncService.instance.resumeAfterSwitch();
    }
    // sign-OUT: leave the current per-account DB active (Model E:
    // reads/writes keep working, sync is just paused). No resume.
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver, WindowListener {
  late Future<bool> _isFirstRun;
  bool _isFirstRunCached = false;
  late ThemeMode _currentThemeMode;
  late VisualStyle _currentVisualStyle;
  late bool _isDark;
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _initializationFuture = _initializeThemeAndStyle();
    themeNotifier.addListener(_updateThemeAndStyle);
    styleNotifier.addListener(_updateThemeAndStyle);
    DatabaseService.instance.activeDbRevision.addListener(_onActiveDbChanged);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_updateThemeAndStyle);
    styleNotifier.removeListener(_updateThemeAndStyle);
    DatabaseService.instance.activeDbRevision.removeListener(_onActiveDbChanged);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    IdleDetector.instance.touch();
    return false;
  }

  @override
  void onWindowFocus() {
    windowFocusedNotifier.value = true;
    IdleDetector.instance.touch();
  }

  @override
  void onWindowBlur() {
    windowFocusedNotifier.value = false;
  }

  void _onActiveDbChanged() {
    if (!mounted) return;
    _checkFirstRun().then((value) {
      if (!mounted) return;
      if (_isFirstRunCached != value) {
        setState(() => _isFirstRunCached = value);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final activeId = PocketBaseService.instance.client.authStore.record?.id;
      unawaited(AccountRegistry.instance.touch(activeId));
      SyncService.instance.requestSync(reason: 'wake');
      unawaited(UpdateService.instance.checkForUpdate());
    }
  }

  Future<void> _initializeThemeAndStyle() async {
    // Ensure WidgetsFlutterBinding is initialized (already in main but good practice)
    WidgetsFlutterBinding.ensureInitialized();
    // Re-check and set notifiers if main didn't
    final prefs = await SharedPreferences.getInstance();
    final themeIndex =
        prefs.getInt(DatabaseService.prefixedKey('theme_mode')) ?? 0;
    themeNotifier.value = ThemeMode.values[themeIndex];
    final styleIndex =
        prefs.getInt(DatabaseService.prefixedKey('visual_style')) ?? 0;
    styleNotifier.value = VisualStyle.values[styleIndex];

    // Initialize state variables *after* notifiers are guaranteed set
    _currentThemeMode = themeNotifier.value;
    _currentVisualStyle = styleNotifier.value;

    // Calculate initial _isDark based on system brightness if ThemeMode.system
    _isDark = _currentThemeMode == ThemeMode.dark ||
        (_currentThemeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);

    // Also set _isFirstRun here as it depends on DatabaseService which needs init
    _isFirstRun = _checkFirstRun();
    _isFirstRunCached = await _isFirstRun; // Wait for first run check to complete
  }

  void _updateThemeAndStyle() {
    if (mounted) {
      setState(() {
        _currentThemeMode = themeNotifier.value;
        _currentVisualStyle = styleNotifier.value;
        // Recalculate _isDark based on the new values
        _isDark = _currentThemeMode == ThemeMode.dark ||
            (_currentThemeMode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark);
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
                        MediaQuery.platformBrightnessOf(context) ==
                            Brightness.dark))
                ? const Color(0xFF09090B) // Dark background
                : Colors.white, // Light background
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                  child: Text('Error initializing app: ${snapshot.error}')),
            ),
          );
        }

        // Only build MaterialApp once initialization is complete
        final primaryColor =
            StyleService.getPrimaryColor(_currentVisualStyle, _isDark);

        return AmbientDim(
          windowFocused: windowFocusedNotifier,
          userActive: userActiveNotifier,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (_) => IdleDetector.instance.touch(),
            onPointerDown: (_) => IdleDetector.instance.touch(),
            child: MaterialApp(
              title: 'Consistency Tracker',
          themeMode: _currentThemeMode,
          theme: ThemeData(
            textTheme: _buildAppTextTheme(Brightness.light),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey,
              primary: primaryColor,
              surface: Colors.white,
              onSurface: const Color(0xFF09090B),
              tertiary: const Color(0xFFEA580C),
              error: const Color(0xFFDC2626),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintStyle:
                  const TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: _currentVisualStyle == VisualStyle.vibrant
                    ? Colors.white
                    : Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            dividerTheme: const DividerThemeData(
              thickness: 1,
              color: Color(0xFFF4F4F5),
              space: 1,
            ),
          ),
          darkTheme: ThemeData(
            textTheme: _buildAppTextTheme(Brightness.dark),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.grey,
              brightness: Brightness.dark,
              primary: primaryColor,
              surface: const Color(0xFF09090B),
              onSurface: Colors.white,
              tertiary: const Color(0xFFFB923C),
              error: const Color(0xFFF87171),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintStyle:
                  const TextStyle(color: Color(0xFF27272A), fontSize: 14),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor:
                    _isDark && _currentVisualStyle == VisualStyle.minimalist
                        ? const Color(0xFF09090B)
                        : Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.5),
              ),
            ),
            dividerTheme: const DividerThemeData(
              thickness: 1,
              color: Color(0xFF18181B),
              space: 1,
            ),
          ),
          debugShowCheckedModeBanner: false,
          home: _isFirstRunCached
              ? const FirstRunSetupScreen()
              : const HomeScreen(),
            ),
          ),
        );
      },
    );
  }
}

TextTheme _buildAppTextTheme(Brightness brightness) {
  final base = brightness == Brightness.dark
      ? ThemeData.dark().textTheme
      : ThemeData.light().textTheme;
  return GoogleFonts.interTextTheme(base).copyWith(
    displayLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
    headlineSmall: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
    titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2),
    labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    labelMedium: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
  );
}
