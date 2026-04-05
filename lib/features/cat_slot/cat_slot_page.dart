import 'package:flutter/material.dart';
import 'cat_slot_controller.dart';
import 'cat_slot_styles.dart';
import 'services/audio_service.dart';
import 'widgets/balance_label.dart';
import 'widgets/reel_box.dart';
import 'widgets/reset_button.dart';
import 'widgets/spin_button.dart';
import 'widgets/result_label.dart';

class CatSlotPage extends StatefulWidget {
  const CatSlotPage({super.key});

  @override
  State<CatSlotPage> createState() => _CatSlotPageState();
}

class _CatSlotPageState extends State<CatSlotPage> {
  final CatSlotController _controller = CatSlotController();
  final AudioService _audio = AudioService();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _onSpin() async {
    await _audio.ensureUnlocked();
    _audio.playSpinSound();
    await _controller.spin(() => setState(() {}));
    if (_controller.result == 'You win!') {
      _audio.playWinSound();
    }
  }

  void _onReset() {
    setState(() {
      _controller.resetGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CatSlotStyles.scaffoldBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(CatSlotStyles.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cat Slot',
                style: TextStyle(
                  fontSize: CatSlotStyles.titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: CatSlotStyles.titleSpacing),
              BalanceLabel(coins: _controller.coins),
              const SizedBox(height: CatSlotStyles.sectionSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ReelBox(
                    emoji: _controller.slots[0],
                    animateKey: ValueKey('0-${_controller.slots[0]}-${_controller.spinTick}'),
                  ),
                  const SizedBox(width: CatSlotStyles.reelSpacing),
                  ReelBox(
                    emoji: _controller.slots[1],
                    animateKey: ValueKey('1-${_controller.slots[1]}-${_controller.spinTick}'),
                  ),
                  const SizedBox(width: CatSlotStyles.reelSpacing),
                  ReelBox(
                    emoji: _controller.slots[2],
                    animateKey: ValueKey('2-${_controller.slots[2]}-${_controller.spinTick}'),
                  ),
                ],
              ),
              const SizedBox(height: CatSlotStyles.sectionSpacing),
              if (_controller.coins > 0)
                SpinButton(
                  isSpinning: _controller.isSpinning,
                  onPressed: _controller.isSpinning ? null : _onSpin,
                )
              else
                ResetButton(onPressed: _onReset),
              const SizedBox(height: CatSlotStyles.sectionSpacing),
              ResultLabel(text: _controller.result),
            ],
          ),
        ),
      ),
    );
  }
}
