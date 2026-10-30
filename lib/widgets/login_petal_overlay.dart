import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A short, non-interactive peach-blossom celebration shown after login.
class LoginPetalOverlay extends StatefulWidget {
  const LoginPetalOverlay({super.key});

  @override
  State<LoginPetalOverlay> createState() => _LoginPetalOverlayState();
}

class _LoginPetalOverlayState extends State<LoginPetalOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..forward();
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _PeachPetalPainter(_animation),
        size: Size.infinite,
      ),
    );
  }
}

class _PeachPetalPainter extends CustomPainter {
  _PeachPetalPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;
  static const _colors = [
    Color(0xFFE991B1),
    Color(0xFFF4B5C8),
    Color(0xFFD976A2),
    Color(0xFFFFC6D6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress.value;
    for (var i = 0; i < 34; i++) {
      final seed = i * 137.508;
      final phase = (i * .371) % 1;
      final y = ((phase + t * 1.45) % 1.12) * size.height - size.height * .06;
      final drift = math.sin(t * 9 + i * 1.7) * 34;
      final x = ((seed + drift + size.width * .12) % (size.width + 40)) - 20;
      final radius = 5.5 + (i % 5) * 1.15;
      final rotation = t * 8 + i * .83;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: .82)
        ..style = PaintingStyle.fill;

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(rotation);
      final petal = Path()
        ..moveTo(0, -radius)
        ..cubicTo(
          radius * .9,
          -radius * .55,
          radius * .95,
          radius * .55,
          0,
          radius,
        )
        ..cubicTo(
          -radius * .95,
          radius * .55,
          -radius * .9,
          -radius * .55,
          0,
          -radius,
        )
        ..close();
      canvas
        ..drawPath(petal, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PeachPetalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
