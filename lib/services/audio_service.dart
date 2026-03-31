// lib/services/audio_service.dart

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  timerEnd,       // Any timer (Focus or Break) hits zero
  goalReached     // Daily goal hit (Celebration)
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  // JustAudio players for robust desktop performance
  // Using two players to allow overlapping/celebration sounds without interrupting timer ends
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

    // Pre-load the current pack files
    await _loadCurrentPack();
  }

  Future<void> _loadCurrentPack() async {
    try {
      final packStr = currentPack.value.toString().split('.').last;
      
      // JustAudio can load directly from assets with 'asset:///' prefix 
      // or using the convenience method.
      await _timerPlayer.setAsset('assets/sounds/$packStr/timer_end.ogg');
      await _goalPlayer.setAsset('assets/sounds/$packStr/goal_reached.ogg');
      
      debugPrint('AudioService: Pre-loaded $packStr pack with JustAudio.');
    } catch (e) {
      debugPrint('AudioService: Error pre-loading pack: $e');
    }
  }

  Future<void> setPack(SoundPack pack) async {
    currentPack.value = pack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sound_pack', pack.index);
    await _loadCurrentPack();
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
      // For desktop, it's safer to stop/seek to zero for instant replay
      if (player.playing) {
        await player.stop();
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      debugPrint('AudioService: Playback Error ($type): $e');
    }
  }

  void dispose() {
    try {
      _timerPlayer.dispose();
      _goalPlayer.dispose();
    } catch (e) {
      debugPrint('AudioService: Error during disposal: $e');
    }
  }
}
