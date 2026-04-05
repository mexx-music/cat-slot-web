import 'dart:async';
import 'dart:web_audio' as web_audio;

class AudioService {
  web_audio.AudioContext? _ctx;
  bool _unlocked = false;

  Future<void> ensureUnlocked() async {
    _ctx ??= web_audio.AudioContext();

    if (_ctx!.state == 'suspended') {
      await _ctx!.resume();
    }

    if (_unlocked) return;

    _playTone(
      frequency: 440,
      durationMs: 20,
      volume: 0.0001,
    );

    _unlocked = true;
  }

  void playSpinSound() {
    if (!_canPlay) return;

    _playTone(
      frequency: 520,
      durationMs: 80,
      volume: 0.04,
    );
  }

  void playWinSound() {
    if (!_canPlay) return;

    _playTone(
      frequency: 660,
      durationMs: 90,
      volume: 0.05,
    );

    Timer(const Duration(milliseconds: 110), () {
      _playTone(
        frequency: 880,
        durationMs: 120,
        volume: 0.05,
      );
    });
  }

  bool get _canPlay => _unlocked && _ctx != null;

  void _playTone({
    required num frequency,
    required int durationMs,
    required num volume,
  }) {
    final ctx = _ctx;
    if (ctx == null) return;

    final oscillator = ctx.createOscillator();
    final gain = ctx.createGain();

    oscillator.type = 'sine';
    oscillator.frequency?.value = frequency.toDouble();
    gain.gain?.value = volume.toDouble();

    oscillator.connectNode(gain);

    final destination = ctx.destination;
    if (destination != null) {
      gain.connectNode(destination);
    }

    oscillator.start2();

    Timer(Duration(milliseconds: durationMs), () {
      oscillator.stop();
      oscillator.disconnect();
      gain.disconnect();
    });
  }

  Future<void> dispose() async {
    await _ctx?.close();
  }
}