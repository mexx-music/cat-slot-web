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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CatSlotStyles.pagePadding,
                vertical: CatSlotStyles.pagePadding,
              ),
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
                  SizedBox(
                    width: CatSlotStyles.reelRowWidth,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ReelBox(
                          key: const ValueKey(0),
                          symbols: _controller.reels[0],
                          spinning: _controller.reelSpinning[0],
                        ),
                        ReelBox(
                          key: const ValueKey(1),
                          symbols: _controller.reels[1],
                          spinning: _controller.reelSpinning[1],
                        ),
                        ReelBox(
                          key: const ValueKey(2),
                          symbols: _controller.reels[2],
                          spinning: _controller.reelSpinning[2],
                        ),
                      ],
                    ),
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
        ),
      ),
    );
  }
}
