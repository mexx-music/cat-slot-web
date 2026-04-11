// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js_interop';

// ─── Minimale Web Audio API Bindings ────────────────────────────────────────

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external factory _AudioContext();
  external String get state;
  external double get currentTime;
  external double get sampleRate;
  external JSPromise<JSAny?> resume();
  external JSPromise<JSAny?> close();
  external _GainNode createGain();
  external _OscillatorNode createOscillator();
  external _AudioBuffer createBuffer(int channels, int length, double sampleRate);
  external _AudioBufferSourceNode createBufferSource();
  external _AudioDestinationNode get destination;
}

@JS()
extension type _AudioDestinationNode._(JSObject _) implements JSObject {}

@JS()
extension type _AudioNode._(JSObject _) implements JSObject {
  external void connect(JSObject destination);
  external void disconnect();
}

@JS()
extension type _AudioParam._(JSObject _) implements JSObject {
  external set value(double v);
  external double get value;
  external void setValueAtTime(double value, double time);
  external void linearRampToValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

@JS()
extension type _GainNode._(JSObject _) implements _AudioNode {
  external _AudioParam get gain;
}

@JS()
extension type _OscillatorNode._(JSObject _) implements _AudioNode {
  external set type(String t);
  external _AudioParam get frequency;
  external void start(double when);
  external void stop(double when);
}

@JS()
extension type _AudioBuffer._(JSObject _) implements JSObject {
  external JSFloat32Array getChannelData(int channel);
}

@JS()
extension type _AudioBufferSourceNode._(JSObject _) implements _AudioNode {
  external set buffer(_AudioBuffer? b);
  external void start(double when);
  external void stop(double when);
}

// ─── AudioService ────────────────────────────────────────────────────────────

/// Synthetischer Audio-Service für Cat Slot.
/// Alle Sounds werden direkt über die Web Audio API erzeugt –
/// kein audioplayers, keine MP3/WAV-Dateien.
/// Präzises Timing auf Desktop + iPhone/iPad Safari.
class AudioService {
  _AudioContext? _ctx;
  bool _unlocked = false;

  _OscillatorNode? _purrOsc;
  _OscillatorNode? _purrMod;
  _GainNode?       _purrGain;
  bool _purrRunning = false;

  // ── Unlock ──────────────────────────────────────────────────

  Future<void> ensureUnlocked() => ensureUnlockedAndPreload();

  Future<void> ensureUnlockedAndPreload() async {
    if (_unlocked || !kIsWeb) return;
    _ctx ??= _AudioContext();
    if (_ctx!.state == 'suspended') {
      await _ctx!.resume().toDart;
    }
    _unlocked = true;
  }

  _AudioContext? get _safe {
    if (!_unlocked) return null;
    return _ctx;
  }

  double get _now => _ctx?.currentTime ?? 0.0;

  // ── Helpers ──────────────────────────────────────────────────

  void _connect(_AudioNode src, _AudioNode dst) => src.connect(dst as JSObject);
  void _connectDest(_AudioNode src, _AudioContext ctx) =>
      src.connect(ctx.destination as JSObject);
  void _connectParam(_AudioNode src, _AudioParam param) =>
      src.connect(param as JSObject);

  // ── Purr-Loop ────────────────────────────────────────────────

  void startPurrLoop() {
    final ctx = _safe;
    if (ctx == null || _purrRunning) return;
    final t = _now;

    final mod = ctx.createOscillator();
    mod.type = 'sine';
    mod.frequency.value = 20; // ruhigeres Vibrato

    final modGain = ctx.createGain();
    modGain.gain.value = 6; // weniger Frequenzabweichung

    final osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.value = 40; // tiefer und ruhiger

    final gain = ctx.createGain();
    gain.gain.setValueAtTime(0, t);
    gain.gain.linearRampToValueAtTime(0.05, t + 0.3); // leiser

    _connect(mod, modGain);
    _connectParam(modGain, osc.frequency);
    _connect(osc, gain);
    _connectDest(gain, ctx);

    mod.start(0);
    osc.start(0);

    _purrOsc  = osc;
    _purrMod  = mod;
    _purrGain = gain;
    _purrRunning = true;
  }

  void stopPurrLoop() {
    if (!_purrRunning) return;
    final t = _now;
    _purrGain?.gain.linearRampToValueAtTime(0, t + 0.15);
    final osc = _purrOsc; final mod = _purrMod; final gain = _purrGain;
    Timer(const Duration(milliseconds: 200), () {
      try { osc?.stop(0); } catch (_) {}
      try { mod?.stop(0); } catch (_) {}
      try { osc?.disconnect(); } catch (_) {}
      try { mod?.disconnect(); } catch (_) {}
      try { gain?.disconnect(); } catch (_) {}
    });
    _purrOsc = null; _purrMod = null; _purrGain = null;
    _purrRunning = false;
  }

  void playSpinSound({int durationMs = 1500}) => startPurrLoop();

  // ── Reel-Stop ────────────────────────────────────────────────

  void playReelStopSound(int reelIndex) {
    final ctx = _safe;
    if (ctx == null) return;
    final t = _now;
    final baseFreq = 460.0 + reelIndex * 30.0;

    final osc = ctx.createOscillator();
    osc.type = 'triangle';
    osc.frequency.setValueAtTime(baseFreq, t);
    osc.frequency.exponentialRampToValueAtTime(200, t + 0.08);

    final gain = ctx.createGain();
    gain.gain.setValueAtTime(0.18, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.10);

    _connect(osc, gain);
    _connectDest(gain, ctx);
    osc.start(t);
    osc.stop(t + 0.12);
  }

  void playStopSound() {}

  // ── Win-Sound ────────────────────────────────────────────────

  void playWinSound() {
    final ctx = _safe;
    if (ctx == null) return;
    stopPurrLoop();
    const freqs = [523.25, 659.25, 783.99, 1046.5];
    const vols  = [0.22,   0.20,   0.18,   0.25];
    final t = _now;
    for (int i = 0; i < freqs.length; i++) {
      _chime(ctx, freqs[i], vols[i], t + i * 0.12, dur: 0.38);
    }
  }

  void _chime(_AudioContext ctx, double freq, double vol, double t,
      {double dur = 0.3}) {
    final osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, t);

    final gain = ctx.createGain();
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + dur);

    _connect(osc, gain);
    _connectDest(gain, ctx);
    osc.start(t);
    osc.stop(t + dur + 0.01);
  }

  // ── Collect-Sound ────────────────────────────────────────────

  void playCollectSound() {
    final ctx = _safe;
    if (ctx == null) return;
    final t = _now;
    _chime(ctx, 1318.5, 0.18, t,        dur: 0.18);
    _chime(ctx, 1567.0, 0.14, t + 0.06, dur: 0.16);
    _noiseBurst(ctx, t, dur: 0.08, vol: 0.055);
  }

  void _noiseBurst(_AudioContext ctx, double t,
      {double dur = 0.1, double vol = 0.05}) {
    final sr = ctx.sampleRate.toInt();
    final n  = (sr * dur).toInt();
    final buf = ctx.createBuffer(1, n, ctx.sampleRate);
    final data = buf.getChannelData(0).toDart;
    final rng = math.Random();
    for (int i = 0; i < n; i++) {
      data[i] = (rng.nextDouble() * 2 - 1) * 0.8;
    }

    final src = ctx.createBufferSource();
    src.buffer = buf;

    final gain = ctx.createGain();
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + dur);

    _connect(src, gain);
    _connectDest(gain, ctx);
    src.start(t);
    src.stop(t + dur + 0.01);
  }

  // ── Dispose ──────────────────────────────────────────────────

  Future<void> dispose() async {
    stopPurrLoop();
    try { await _ctx?.close().toDart; } catch (_) {}
    _ctx = null;
    _unlocked = false;
  }
}
