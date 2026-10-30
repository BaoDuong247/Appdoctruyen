import 'package:flutter/material.dart';

/// The supplied TAMBAO mark has a white background, so keep it on a compact
/// white tile wherever it appears over the app's colored surfaces.
class TambaoLogo extends StatelessWidget {
  const TambaoLogo({
    super.key,
    this.width = 52,
    this.height = 48,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: Colors.white,
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Image.asset('assets/tambao-logo.png', fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
