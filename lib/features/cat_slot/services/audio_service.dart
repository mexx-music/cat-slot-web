import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Einfacher Audio-Service für Cat Slot SFX.
///
/// Asset-Pfade:
///   assets/audio/spin.mp3
///   assets/audio/stop.mp3          ← für alle 3 Rollen (gleiche Datei)
///   assets/audio/stop_reel_0.mp3   ← optional: eigener Sound für Rolle 0
///   assets/audio/stop_reel_1.mp3   ← optional: eigener Sound für Rolle 1
///   assets/audio/stop_reel_2.mp3   ← optional: eigener Sound für Rolle 2
///   assets/audio/win.mp3
///   assets/audio/collect.mp3
class AudioService {
  final AudioPlayer _spinPlayer    = AudioPlayer();
  // 3 separate Player für Reel-Stops (parallel abspielbar)
  final List<AudioPlayer> _reelStopPlayers = [
    AudioPlayer(),
    AudioPlayer(),
    AudioPlayer(),
  ];
  final AudioPlayer _winPlayer     = AudioPlayer();
  final AudioPlayer _collectPlayer = AudioPlayer();

  bool _unlocked = false;
  Timer? _spinStopTimer;

  // Dateiname je Reel – einfach durch eigene Datei ersetzen wenn vorhanden
  static const List<String> _reelStopSounds = [
    'audio/stop_reel_0.mp3',
    'audio/stop_reel_1.mp3',
    'audio/stop_reel_2.mp3',
  ];
  // Fallback falls reel-spezifische Datei nicht vorhanden
  static const String _stopFallback = 'audio/stop.mp3';

  Future<void> ensureUnlocked() async {
    if (_unlocked) return;
    _unlocked = true;
  }

  /// Spin-Sound – stoppt automatisch nach [durationMs] ms.
  void playSpinSound({int durationMs = 1500}) {
    if (!_unlocked) return;
    _spinStopTimer?.cancel();
    _spinPlayer.stop();
    _spinPlayer.play(AssetSource('audio/spin.mp3'), volume: 0.6);
    _spinStopTimer = Timer(Duration(milliseconds: durationMs), () {
      _spinPlayer.stop();
    });
  }

  /// Stop-Sound für eine einzelne Rolle (index 0–2).
  /// Spielt reel-spezifischen Sound, Fallback auf stop.mp3.
  void playReelStopSound(int reelIndex) {
    if (!_unlocked) return;
    if (reelIndex < 0 || reelIndex > 2) return;
    final player = _reelStopPlayers[reelIndex];
    player.stop();
    // Versuche reel-spezifischen Sound, errorHandler fällt auf Fallback zurück
    player.play(
      AssetSource(_reelStopSounds[reelIndex]),
      volume: 0.65,
    ).catchError((_) {
      player.play(AssetSource(_stopFallback), volume: 0.65);
    });
  }

  /// Letzter Reel gestoppt – spielt keinen extra Sound mehr
  /// (der letzte playReelStopSound-Aufruf reicht).
  void playStopSound() {
    // Kept for backwards compatibility – no-op, replaced by playReelStopSound
  }

  void playWinSound() {
    if (!_unlocked) return;
    _winPlayer.stop();
    _winPlayer.play(AssetSource('audio/win.mp3'), volume: 0.8);
  }

  void playCollectSound() {
    if (!_unlocked) return;
    _collectPlayer.stop();
    _collectPlayer.play(AssetSource('audio/collect.mp3'), volume: 0.75);
  }

  Future<void> dispose() async {
    _spinStopTimer?.cancel();
    await _spinPlayer.dispose();
    for (final p in _reelStopPlayers) {
      await p.dispose();
    }
    await _winPlayer.dispose();
    await _collectPlayer.dispose();
  }
}

