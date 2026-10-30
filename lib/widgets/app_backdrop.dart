import 'package:flutter/material.dart';

/// Soft lavender/peach page background that remains readable in both themes.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [
                      Color(0xFF17131E),
                      Color(0xFF211722),
                      Color(0xFF191724),
                    ]
                  : const [
                      Color(0xFFF6ECFF),
                      Color(0xFFFFF0F3),
                      Color(0xFFF3E9FF),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: -110,
          child: _BackdropOrb(
            size: 260,
            color: isDark ? const Color(0x263E2D55) : const Color(0x267F4CC3),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -100,
          child: _BackdropOrb(
            size: 230,
            color: isDark ? const Color(0x263D2636) : const Color(0x20E58CAC),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
