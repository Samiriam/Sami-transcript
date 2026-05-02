import 'package:flutter/material.dart';

class GothicLogo extends StatelessWidget {
  const GothicLogo({super.key, this.size = 72, this.showLabel = true});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GothicLogoMark(size: size),
        if (showLabel) ...[
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SAMI',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'TRANSCRIBE',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GothicLogoMark extends StatelessWidget {
  const _GothicLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFD8B15A);
    const topColor = Color(0xFF341421);
    const bottomColor = Color(0xFF0F0B14);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _ShieldClipper(),
            child: Container(color: borderColor),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.075),
            child: ClipPath(
              clipper: _ShieldClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topColor, bottomColor],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: size * 0.14,
            child: Container(
              width: size * 0.34,
              height: 1.4,
              color: borderColor.withValues(alpha: 0.9),
            ),
          ),
          Positioned(
            bottom: size * 0.12,
            child: Container(
              width: size * 0.30,
              height: 1.4,
              color: borderColor.withValues(alpha: 0.9),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_rounded,
                size: size * 0.34,
                color: borderColor,
              ),
              const SizedBox(height: 2),
              Text(
                'ST',
                style: TextStyle(
                  color: borderColor,
                  fontSize: size * 0.24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.95, h * 0.18)
      ..lineTo(w * 0.83, h * 0.88)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.17, h * 0.88)
      ..lineTo(w * 0.05, h * 0.18)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
