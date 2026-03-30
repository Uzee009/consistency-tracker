// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  focusEnd, // Time is up / Each session end
  shortBreakEnd, // When break is up
  longBreakStart, // When it's a long break time
  goalReached // Celebration!
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1; // Default to minimal
    final enabled = prefs.getBool('sound_enabled') ?? true;
    
    currentPack.value = SoundPack.values[packIndex];
    isEnabled.value = enabled;
  }

  Future<void> setPack(SoundPack pack) async {
    currentPack.value = pack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sound_pack', pack.index);
  }

  Future<void> toggleEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> playSound(AudioType type) async {
    if (!isEnabled.value) return;

    final packStr = currentPack.value.toString().split('.').last;
    String fileName;

    switch (type) {
      case AudioType.focusEnd:
        fileName = 'focus_end.mp3';
        break;
      case AudioType.shortBreakEnd:
        fileName = 'break_end.mp3';
        break;
      case AudioType.longBreakStart:
        fileName = 'long_break_start.mp3';
        break;
      case AudioType.goalReached:
        fileName = 'goal_reached.mp3';
        break;
    }

    try {
      // AssetSource expects path relative to assets/
      await _player.stop(); // Stop any currently playing sound
      await _player.play(AssetSource('sounds/$packStr/$fileName'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Preview helper
  String getSoundPath(SoundPack pack, AudioType type) {
    final packStr = pack.toString().split('.').last;
    String fileName;
    switch (type) {
      case AudioType.focusEnd: fileName = 'focus_end.mp3'; break;
      case AudioType.shortBreakEnd: fileName = 'break_end.mp3'; break;
      case AudioType.longBreakStart: fileName = 'long_break_start.mp3'; break;
      case AudioType.goalReached: fileName = 'goal_reached.mp3'; break;
    }
    return 'assets/sounds/$packStr/$fileName';
  }
}
