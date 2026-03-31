// lib/services/audio_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  timerEnd,       // Any timer (Focus or Break) hits zero
  goalReached     // Daily goal hit (Celebration)
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  // JustAudio players for robust desktop performance
  final AudioPlayer _timerPlayer = AudioPlayer();
  final AudioPlayer _goalPlayer = AudioPlayer();
  
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

  /// Loads the sound files for a specific pack into local storage and pre-loads the players
  Future<void> loadPack(SoundPack pack) async {
    try {
      final packStr = pack.toString().split('.').last;
      final docDir = await getApplicationSupportDirectory();
      
      // 1. Prepare Timer End sound
      final timerData = await rootBundle.load("assets/sounds/$packStr/timer_end.mp3");
      final timerFile = File("${docDir.path}/sound_timer_end_${packStr}.mp3");
      await timerFile.writeAsBytes(timerData.buffer.asUint8List());
      await _timerPlayer.setFilePath(timerFile.path);
          
      // 2. Prepare Goal Reached sound
      final goalData = await rootBundle.load("assets/sounds/$packStr/goal_reached.mp3");
      final goalFile = File("${docDir.path}/sound_goal_reached_${packStr}.mp3");
      await goalFile.writeAsBytes(goalData.buffer.asUint8List());
      await _goalPlayer.setFilePath(goalFile.path);
          
      debugPrint('AudioService: JustAudio ready with pack $packStr.');
    } catch (e) {
      debugPrint('AudioService: Error pre-loading with JustAudio: $e');
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

    final player = (type == AudioType.timerEnd) ? _timerPlayer : _goalPlayer;
    
    try {
      // V11: Instant play logic for JustAudio
      if (player.playing) {
        await player.stop();
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('AudioService: JustAudio Playback Error ($type): $e');
    }
  }

  // Dispose players when app closes (optional but good practice)
  void dispose() {
    _timerPlayer.dispose();
    _goalPlayer.dispose();
  }
}
