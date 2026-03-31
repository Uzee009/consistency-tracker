// lib/services/audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  
  // Buffers to store pre-loaded audio bytes
  final Map<AudioType, Uint8List> _bufferCache = {};
  
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1; // Default to minimal
    final enabled = prefs.getBool('sound_enabled') ?? true;
    
    currentPack.value = SoundPack.values[packIndex];
    isEnabled.value = enabled;

    // V11: Set players to low latency if available on platform
    // AudioPlayers 5.x handles this via PlayerMode
    
    // Pre-load the current pack
    await loadPack(currentPack.value);
  }

  /// Loads the sound files for a specific pack into memory buffers
  Future<void> loadPack(SoundPack pack) async {
    try {
      _bufferCache.clear();
      final packStr = pack.toString().split('.').last;
      
      // Pre-load bytes from assets into memory
      final timerData = await rootBundle.load("assets/sounds/$packStr/timer_end.mp3");
      _bufferCache[AudioType.timerEnd] = timerData.buffer.asUint8List();
          
      final goalData = await rootBundle.load("assets/sounds/$packStr/goal_reached.mp3");
      _bufferCache[AudioType.goalReached] = goalData.buffer.asUint8List();
          
      debugPrint('AudioService: Buffers loaded for pack $packStr.');
    } catch (e) {
      debugPrint('AudioService: Error pre-loading buffers: $e');
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

    final bytes = _bufferCache[type];
    if (bytes != null) {
      final player = (type == AudioType.timerEnd) ? _timerPlayer : _goalPlayer;
      try {
        // V11: Stop and play from BytesSource (Memory)
        await player.stop();
        await player.play(BytesSource(bytes));
      } catch (e) {
        debugPrint('AudioService: Error playing sound from buffer: $e');
      }
    } else {
      debugPrint('AudioService: Buffer for $type not found.');
    }
  }
}
