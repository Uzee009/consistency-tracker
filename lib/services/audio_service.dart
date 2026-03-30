// lib/services/audio_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundpool/soundpool.dart';

enum SoundPack { zen, minimal, retro }

enum AudioType { 
  timerEnd,       // Any timer (Focus or Break) hits zero
  goalReached     // Daily goal hit (Celebration)
}

class AudioService {
  static final AudioService instance = AudioService._constructor();
  
  late Soundpool _pool;
  final Map<AudioType, int> _soundCache = {};
  
  final ValueNotifier<SoundPack> currentPack = ValueNotifier(SoundPack.minimal);
  final ValueNotifier<bool> isEnabled = ValueNotifier(true);
  
  AudioService._constructor();

  Future<void> initialize() async {
    // Initialize soundpool for soundpool 2.x API
    _pool = Soundpool(streamType: StreamType.notification);

    final prefs = await SharedPreferences.getInstance();
    final packIndex = prefs.getInt('sound_pack') ?? 1; // Default to minimal
    final enabled = prefs.getBool('sound_enabled') ?? true;
    
    currentPack.value = SoundPack.values[packIndex];
    isEnabled.value = enabled;

    // Pre-load the current pack
    await loadPack(currentPack.value);
  }

  /// Loads the sound files for a specific pack into memory
  Future<void> loadPack(SoundPack pack) async {
    try {
      // Clear existing cache to save memory
      for (var id in _soundCache.values) {
        await _pool.unload(id);
      }
      _soundCache.clear();

      final packStr = pack.toString().split('.').last;
      
      // Load assets into memory buffer
      _soundCache[AudioType.timerEnd] = await rootBundle.load("assets/sounds/$packStr/timer_end.mp3")
          .then((ByteData data) => _pool.load(data));
          
      _soundCache[AudioType.goalReached] = await rootBundle.load("assets/sounds/$packStr/goal_reached.mp3")
          .then((ByteData data) => _pool.load(data));
          
      debugPrint('AudioService: Loaded pack $packStr into memory.');
    } catch (e) {
      debugPrint('AudioService: Error loading pack: $e');
    }
  }

  Future<void> setPack(SoundPack pack) async {
    currentPack.value = pack;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sound_pack', pack.index);
    // Reload memory cache when pack changes
    await loadPack(pack);
  }

  Future<void> toggleEnabled(bool enabled) async {
    isEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> playSound(AudioType type) async {
    if (!isEnabled.value) return;

    final soundId = _soundCache[type];
    if (soundId != null) {
      try {
        await _pool.play(soundId);
      } catch (e) {
        debugPrint('AudioService: Error playing sound $type: $e');
      }
    } else {
      debugPrint('AudioService: Sound $type not found in cache.');
    }
  }
}
