import 'package:flutter/material.dart';

class CatSwitchPortrait extends StatelessWidget {
  final bool target;
  final double size;
  final bool celebrating;
  final String? assetPath;

  const CatSwitchPortrait({
    super.key,
    required this.target,
    this.size = 120,
    this.celebrating = false,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: target ? 'Bonuskatze' : 'Ablenkkatze',
    child: SizedBox.square(
      dimension: size,
      child: assetPath == null
          ? CustomPaint(
              painter: _SwitchCatPainter(
                target: target,
                celebrating: celebrating,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: target
                            ? const Color(0x668CE4DC)
                            : const Color(0x554D376D),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      assetPath!,
                      width: size * .88,
                      height: size * .88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => CustomPaint(
                        size: Size.square(size),
                        painter: _SwitchCatPainter(
                          target: target,
                          celebrating: celebrating,
                        ),
                      ),
                    ),
                  ),
                ),
                if (target)
                  Positioned(
                    bottom: size * .02,
                    child: _GoldenCatTag(size: size * .2),
                  ),
              ],
            ),
    ),
  );
}

class _GoldenCatTag extends StatelessWidget {
  final double size;

  const _GoldenCatTag({required this.size});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFDF72),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(
        Icons.auto_awesome_rounded,
        size: size * .58,
        color: const Color(0xFF6B4524),
      ),
    ),
  );
}

class CatSwitchSymbol extends StatelessWidget {
  final double size;

  const CatSwitchSymbol({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CatSwitchPortrait(target: true, size: size),
        Positioned(
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF8CE4DC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFE59A), width: 1.5),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: Color(0xFF20152E),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SwitchCatPainter extends CustomPainter {
  final bool target;
  final bool celebrating;

  const _SwitchCatPainter({required this.target, required this.celebrating});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final glow = Paint()
      ..color = target ? const Color(0x448CE4DC) : const Color(0x334D376D);
    canvas.drawCircle(center, s * 0.47, glow);

    final outline = Paint()
      ..color = const Color(0xFF38243C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()
      ..color = target ? const Color(0xFFF4B75B) : const Color(0xFFAA83C2);
    final earLeft = Path()
      ..moveTo(s * 0.20, s * 0.40)
      ..lineTo(s * 0.25, s * 0.08)
      ..lineTo(s * 0.46, s * 0.29)
      ..close();
    final earRight = Path()
      ..moveTo(s * 0.54, s * 0.29)
      ..lineTo(s * 0.75, s * 0.08)
      ..lineTo(s * 0.80, s * 0.40)
      ..close();
    canvas.drawPath(earLeft, outline);
    canvas.drawPath(earRight, outline);
    canvas.drawPath(earLeft, fur);
    canvas.drawPath(earRight, fur);
    canvas.drawCircle(Offset(s * 0.5, s * 0.53), s * 0.31, outline);
    canvas.drawCircle(Offset(s * 0.5, s * 0.53), s * 0.285, fur);

    final face = Paint()
      ..color = const Color(0xFF2D2231)
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round;
    if (celebrating) {
      face.style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromLTWH(s * .31, s * .42, s * .13, s * .08),
        0,
        3.14,
        false,
        face,
      );
      canvas.drawArc(
        Rect.fromLTWH(s * .56, s * .42, s * .13, s * .08),
        0,
        3.14,
        false,
        face,
      );
    } else {
      canvas.drawCircle(Offset(s * .38, s * .50), s * .035, face);
      canvas.drawCircle(Offset(s * .62, s * .50), s * .035, face);
    }
    final nose = Path()
      ..moveTo(s * .45, s * .60)
      ..lineTo(s * .55, s * .60)
      ..lineTo(s * .50, s * .66)
      ..close();
    canvas.drawPath(
      nose,
      Paint()
        ..color = target ? const Color(0xFFDF6D79) : const Color(0xFF6ED5D0),
    );
    if (target) {
      canvas.drawCircle(
        Offset(s * .5, s * .82),
        s * .08,
        Paint()..color = const Color(0xFFFFDF72),
      );
      final star = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawCircle(Offset(s * .5, s * .82), s * .025, star);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(s * .5, s * .82),
            width: s * .28,
            height: s * .09,
          ),
          Radius.circular(s * .04),
        ),
        Paint()..color = const Color(0xFF604778),
      );
    }
  }

  @override
  bool shouldRepaint(_SwitchCatPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.celebrating != celebrating;
}
