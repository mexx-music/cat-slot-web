import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Audio-Service für Cat Slot SFX.
///
/// iOS/iPad-Strategie:
///   Nach der ersten echten User-Interaktion werden ALLE Player
///   mit ihrem Source vorgeladen (setSource + resume + pause).
///   iOS Safari gibt den AudioContext dadurch frei, sodass
///   spätere play()-Aufrufe sofort und ohne Verzögerung feuern.
///
/// Asset-Pfade:
///   assets/audio/purr_loop.mp3     ← Loop während Spin
///   assets/audio/stop.mp3          ← Fallback Reel-Stop
///   assets/audio/stop_reel_0.mp3   ← Miau Rolle 0
///   assets/audio/stop_reel_1.mp3   ← Miau Rolle 1
///   assets/audio/stop_reel_2.mp3   ← Miau Rolle 2
///   assets/audio/win.mp3
///   assets/audio/collect.mp3
class AudioService {
  // ── Player ────────────────────────────────────────────────────
  final AudioPlayer _purrPlayer    = AudioPlayer();
  final List<AudioPlayer> _reelStopPlayers = [
    AudioPlayer(),
    AudioPlayer(),
    AudioPlayer(),
  ];
  final AudioPlayer _winPlayer     = AudioPlayer();
  final AudioPlayer _collectPlayer = AudioPlayer();

  // ── Zustand ───────────────────────────────────────────────────
  bool _unlocked  = false;
  bool _preloaded = false;

  static const String        _purrAsset    = 'audio/purr_loop.mp3';
  static const String        _stopFallback = 'audio/stop.mp3';
  static const List<String>  _reelStopAssets = [
    'audio/stop_reel_0.mp3',
    'audio/stop_reel_1.mp3',
    'audio/stop_reel_2.mp3',
  ];
  static const String _winAsset     = 'audio/win.mp3';
  static const String _collectAsset = 'audio/collect.mp3';

  // ── Unlock + Preload ──────────────────────────────────────────

  /// Muss beim ersten echten User-Tap aufgerufen werden.
  ///
  /// 1. Setzt den iOS Audio-Kontext frei
  /// 2. Lädt alle Sounds in ihre Player (setSource)
  /// 3. Startet jeden Player kurz (resume) und pausiert ihn sofort
  ///    → iOS hält den AudioContext offen, spätere play()-Calls
  ///      feuern ohne merkbare Latenz
  Future<void> ensureUnlockedAndPreload() async {
    if (_unlocked) return;
    _unlocked = true;

    await _preloadAll();
  }

  /// Rückwärts-kompatibel mit bestehendem Code.
  Future<void> ensureUnlocked() => ensureUnlockedAndPreload();

  Future<void> _preloadAll() async {
    if (_preloaded) return;
    _preloaded = true;

    // Purr-Loop vorbereiten (Fallback: spin.mp3 wenn purr_loop fehlt)
    await _warmUp(_purrPlayer,    _purrAsset,    loop: true);

    // Reel-Stop-Sounds
    for (int i = 0; i < 3; i++) {
      await _warmUp(_reelStopPlayers[i], _reelStopAssets[i],
          fallback: _stopFallback);
    }

    // Win + Collect
    await _warmUp(_winPlayer,     _winAsset);
    await _warmUp(_collectPlayer, _collectAsset);
  }

  /// Lädt einen Sound in den Player und macht ihn iOS-bereit.
  Future<void> _warmUp(
    AudioPlayer player,
    String asset, {
    bool loop = false,
    String? fallback,
  }) async {
    try {
      await player.setSource(AssetSource(asset));
      if (loop) {
        await player.setReleaseMode(ReleaseMode.loop);
      } else {
        await player.setReleaseMode(ReleaseMode.stop);
      }
      // iOS: kurz resume + sofort pause → AudioContext wird freigegeben
      await player.resume();
      await Future.delayed(const Duration(milliseconds: 30));
      await player.pause();
      await player.seek(Duration.zero);
    } catch (_) {
      // Fallback versuchen wenn Asset fehlt
      if (fallback != null) {
        try {
          await player.setSource(AssetSource(fallback));
          await player.setReleaseMode(ReleaseMode.stop);
          await player.resume();
          await Future.delayed(const Duration(milliseconds: 30));
          await player.pause();
          await player.seek(Duration.zero);
        } catch (_) {
          // Kein Sound verfügbar – ignorieren
        }
      }
    }
  }

  // ── Purr-Loop (während Spin) ──────────────────────────────────

  void startPurrLoop() {
    if (!_unlocked) return;
    _purrPlayer.setVolume(0.55);
    _purrPlayer.resume();
  }

  void stopPurrLoop() {
    _purrPlayer.stop();
    _purrPlayer.seek(Duration.zero);
  }

  // ── Rückwärts-kompatibel: playSpinSound startet Purr-Loop ─────

  void playSpinSound({int durationMs = 1500}) {
    startPurrLoop();
  }

  // ── Reel-Stop-Sound (Miau pro Rolle) ─────────────────────────

  void playReelStopSound(int reelIndex) {
    if (!_unlocked) return;
    if (reelIndex < 0 || reelIndex > 2) return;
    final player = _reelStopPlayers[reelIndex];
    player.seek(Duration.zero);
    player.resume();
  }

  // no-op für Rückwärtskompatibilität
  void playStopSound() {}

  // ── Win + Collect ─────────────────────────────────────────────

  void playWinSound() {
    if (!_unlocked) return;
    stopPurrLoop(); // Purr stoppen wenn Gewinn
    _winPlayer.seek(Duration.zero);
    _winPlayer.resume();
  }

  void playCollectSound() {
    if (!_unlocked) return;
    _collectPlayer.seek(Duration.zero);
    _collectPlayer.resume();
  }

  // ── Dispose ───────────────────────────────────────────────────

  Future<void> dispose() async {
    await _purrPlayer.dispose();
    for (final p in _reelStopPlayers) {
      await p.dispose();
    }
    await _winPlayer.dispose();
    await _collectPlayer.dispose();
  }
}
