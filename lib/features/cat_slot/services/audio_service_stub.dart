/// Stub-Implementierung von AudioService für Android, iOS und Desktop.
/// Alle Methoden sind No-ops – kein Sound, keine Abhängigkeit von dart:js_interop.
class AudioService {
  Future<void> ensureUnlocked() async {}
  Future<void> ensureUnlockedAndPreload() async {}

  void startPurrLoop() {}
  void stopPurrLoop() {}
  void playSpinSound({int durationMs = 1500}) {}
  void playReelStopSound(int reelIndex) {}
  void playStopSound() {}
  void playWinSound() {}
  void playCollectSound() {}

  Future<void> dispose() async {}
}
