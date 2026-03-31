// lib/services/audio_service.dart

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  timerEnd,       // Any timer (Focus or Break) hits zero
  goalReached     // Daily goal hit (Celebration)
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  final AudioPlayer _timerPlayer = AudioPlayer();
  final AudioPlayer _goalPlayer = AudioPlayer();
  
  // Paths to temporary files for playback
  final Map<AudioType, String> _tempPaths = {};
  
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1; // Default to minimal
    final enabled = prefs.getBool('sound_enabled') ?? true;
    
    currentPack.value = SoundPack.values[packIndex];
    isEnabled.value = enabled;

    // Pre-load the current pack
    await loadPack(currentPack.value);
  }

  /// Loads the sound files for a specific pack into temporary files for robust playback
  Future<void> loadPack(SoundPack pack) async {
    try {
      final packStr = pack.toString().split('.').last;
      final tempDir = await getTemporaryDirectory();
      
      // Load and write Timer End sound
      final timerData = await rootBundle.load("assets/sounds/$packStr/timer_end.mp3");
      final timerFile = File("${tempDir.path}/timer_end_${packStr}.mp3");
      await timerFile.writeAsBytes(timerData.buffer.asUint8List());
      _tempPaths[AudioType.timerEnd] = timerFile.path;
          
      // Load and write Goal Reached sound
      final goalData = await rootBundle.load("assets/sounds/$packStr/goal_reached.mp3");
      final goalFile = File("${tempDir.path}/goal_reached_${packStr}.mp3");
      await goalFile.writeAsBytes(goalData.buffer.asUint8List());
      _tempPaths[AudioType.goalReached] = goalFile.path;
          
      debugPrint('AudioService: Temp files created for pack $packStr.');
    } catch (e) {
      debugPrint('AudioService: Error creating temp files: $e');
    }
  }

  Future<void> setPack(SoundPack pack) async {
    currentPack.value = pack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sound_pack', pack.index);
    // Reload memory buffers when pack changes
    await loadPack(pack);
  }

  Future<void> toggleEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> playSound(AudioType type) async {
    if (!isEnabled.value) return;

    final path = _tempPaths[type];
    if (path != null) {
      final player = (type == AudioType.timerEnd) ? _timerPlayer : _goalPlayer;
      try {
        // V11: Use DeviceFileSource for 100% reliable playback on all platforms (including Linux)
        await player.stop();
        await player.play(DeviceFileSource(path));
      } catch (e) {
        debugPrint('AudioService: Error playing sound from temp file: $e');
      }
    } else {
      debugPrint('AudioService: Temp file for $type not found.');
    }
  }
}
