// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  timerEnd,       // Any timer (Focus or Break) hits zero
  goalReached     // Daily goal hit (Celebration)
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  // Single player for stable UI feedback
  final AudioPlayer _player = AudioPlayer();
  
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1;
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
    String fileName = (type == AudioType.timerEnd) ? 'timer_end.ogg' : 'goal_reached.ogg';

    try {
      // V11: Use standard AssetSource for OGG files (Native Linux format, universal support)
      await _player.play(AssetSource('sounds/$packStr/$fileName'));
    } catch (e) {
      debugPrint('AudioService: Playback Error ($type): $e');
    }
  }
}
