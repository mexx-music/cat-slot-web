import 'package:flutter/material.dart';

class GoldenCatPortrait extends StatelessWidget {
  final bool golden;
  final double size;
  final bool celebrating;
  final bool disappointed;
  final String? assetPath;

  const GoldenCatPortrait({
    super.key,
    required this.golden,
    this.size = 180,
    this.celebrating = false,
    this.disappointed = false,
    this.assetPath,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: golden ? 'Goldene Katze' : 'Normale Katze',
    child: SizedBox.square(
      dimension: size,
      child: assetPath == null
          ? CustomPaint(
              painter: _GoldenCatPainter(
                golden: golden,
                celebrating: celebrating,
                disappointed: disappointed,
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                if (golden)
                  Container(
                    width: size * .92,
                    height: size * .92,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xAAFFD65A),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ClipOval(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      golden ? const Color(0x66FFD45A) : Colors.transparent,
                      golden ? BlendMode.color : BlendMode.dst,
                    ),
                    child: Image.asset(
                      assetPath!,
                      width: size * .86,
                      height: size * .86,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => CustomPaint(
                        size: Size.square(size),
                        painter: _GoldenCatPainter(
                          golden: golden,
                          celebrating: celebrating,
                          disappointed: disappointed,
                        ),
                      ),
                    ),
                  ),
                ),
                if (golden)
                  Positioned(
                    bottom: size * .02,
                    child: _GoldenMedallion(size: size * .22),
                  ),
              ],
            ),
    ),
  );
}

class GoldenCatSymbol extends StatelessWidget {
  final double size;

  const GoldenCatSymbol({super.key, this.size = 68});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        GoldenCatPortrait(golden: true, size: size),
        Positioned(
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFD65A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 1.4),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              child: Icon(
                Icons.bolt_rounded,
                size: 14,
                color: Color(0xFF33200A),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoldenMedallion extends StatelessWidget {
  final double size;

  const _GoldenMedallion({required this.size});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        colors: [Color(0xFFFFF3A3), Color(0xFFFFB52E)],
      ),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(
        Icons.star_rounded,
        size: size * .64,
        color: const Color(0xFF76450B),
      ),
    ),
  );
}

class _GoldenCatPainter extends CustomPainter {
  final bool golden;
  final bool celebrating;
  final bool disappointed;

  const _GoldenCatPainter({
    required this.golden,
    required this.celebrating,
    required this.disappointed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      s * .47,
      Paint()
        ..color = golden ? const Color(0x66FFD659) : const Color(0x334D6A76),
    );
    if (golden) {
      canvas.drawCircle(
        center,
        s * .42,
        Paint()
          ..color = const Color(0xFFFFD65A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * .028,
      );
    }

    final outline = Paint()
      ..color = const Color(0xFF38243C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .045
      ..strokeJoin = StrokeJoin.round;
    final fur = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: golden
            ? const [Color(0xFFFFF09A), Color(0xFFE99A20)]
            : const [Color(0xFFB9C9D2), Color(0xFF718A9A)],
      ).createShader(Rect.fromLTWH(0, 0, s, s));
    final leftEar = Path()
      ..moveTo(s * .20, s * .40)
      ..lineTo(s * .25, s * .08)
      ..lineTo(s * .46, s * .29)
      ..close();
    final rightEar = Path()
      ..moveTo(s * .54, s * .29)
      ..lineTo(s * .75, s * .08)
      ..lineTo(s * .80, s * .40)
      ..close();
    canvas
      ..drawPath(leftEar, outline)
      ..drawPath(rightEar, outline)
      ..drawPath(leftEar, fur)
      ..drawPath(rightEar, fur)
      ..drawCircle(Offset(s * .5, s * .53), s * .31, outline)
      ..drawCircle(Offset(s * .5, s * .53), s * .285, fur);

    final face = Paint()
      ..color = const Color(0xFF2D2231)
      ..strokeWidth = s * .035
      ..strokeCap = StrokeCap.round;
    if (celebrating) {
      face.style = PaintingStyle.stroke;
      canvas
        ..drawArc(
          Rect.fromLTWH(s * .30, s * .43, s * .14, s * .08),
          0,
          3.14,
          false,
          face,
        )
        ..drawArc(
          Rect.fromLTWH(s * .56, s * .43, s * .14, s * .08),
          0,
          3.14,
          false,
          face,
        );
    } else if (disappointed) {
      face.style = PaintingStyle.stroke;
      canvas
        ..drawLine(Offset(s * .31, s * .47), Offset(s * .43, s * .52), face)
        ..drawLine(Offset(s * .57, s * .52), Offset(s * .69, s * .47), face);
    } else {
      canvas
        ..drawCircle(Offset(s * .38, s * .50), s * .035, face)
        ..drawCircle(Offset(s * .62, s * .50), s * .035, face);
    }
    final nose = Path()
      ..moveTo(s * .45, s * .60)
      ..lineTo(s * .55, s * .60)
      ..lineTo(s * .50, s * .66)
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFDF6D79));

    if (golden) {
      canvas.drawCircle(
        Offset(s * .5, s * .82),
        s * .09,
        Paint()..color = const Color(0xFFFFF09A),
      );
      canvas.drawCircle(
        Offset(s * .5, s * .82),
        s * .035,
        Paint()..color = const Color(0xFF9A5C0A),
      );
    }
  }

  @override
  bool shouldRepaint(_GoldenCatPainter oldDelegate) =>
      oldDelegate.golden != golden ||
      oldDelegate.celebrating != celebrating ||
      oldDelegate.disappointed != disappointed;
}
