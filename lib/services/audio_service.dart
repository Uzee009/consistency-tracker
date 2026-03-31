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
  
  // Use a single player for standard UI feedback to keep pipeline stable
  final AudioPlayer _player = AudioPlayer();
  
  // Paths to local files for playback
  final Map<AudioType, String> _localPaths = {};
  
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1;
    final enabled = prefs.getBool('sound_enabled') ?? true;
    
    currentPack.value = SoundPack.values[packIndex];
    isEnabled.value = enabled;

    // Pre-load the current pack
    await loadPack(currentPack.value);
  }

  /// Loads the sound files for a specific pack into app storage for robust playback
  Future<void> loadPack(SoundPack pack) async {
    try {
      final packStr = pack.toString().split('.').last;
      // V11: Use ApplicationSupport (more stable permissions than /tmp/ on Linux)
      final docDir = await getApplicationSupportDirectory();
      
      // Load and write Timer End sound
      final timerData = await rootBundle.load("assets/sounds/$packStr/timer_end.mp3");
      final timerFile = File("${docDir.path}/sound_timer_end_${packStr}.mp3");
      await timerFile.writeAsBytes(timerData.buffer.asUint8List());
      _localPaths[AudioType.timerEnd] = timerFile.path;
          
      // Load and write Goal Reached sound
      final goalData = await rootBundle.load("assets/sounds/$packStr/goal_reached.mp3");
      final goalFile = File("${docDir.path}/sound_goal_reached_${packStr}.mp3");
      await goalFile.writeAsBytes(goalData.buffer.asUint8List());
      _localPaths[AudioType.goalReached] = goalFile.path;
          
      debugPrint('AudioService: Local files prepared in ${docDir.path}');
    } catch (e) {
      debugPrint('AudioService: Error preparing local files: $e');
    }
  }

  Future<void> setPack(SoundPack pack) async {
    currentPack.value = pack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sound_pack', pack.index);
    await loadPack(pack);
  }

  Future<void> toggleEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> playSound(AudioType type) async {
    if (!isEnabled.value) return;

    final path = _localPaths[type];
    if (path != null) {
      try {
        // V11: DIRECT PLAY. 
        // Calling stop() immediately before play() often causes GStreamer state errors on Linux.
        // AudioPlayers handles the interruption internally if already playing.
        await _player.play(DeviceFileSource(path));
      } catch (e) {
        debugPrint('AudioService: Error playing $type: $e');
      }
    }
  }
}
