import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative motion is isolated from form state and never receives touches.
class FloatingCurrencyBackground extends StatefulWidget {
  final Widget child;
  const FloatingCurrencyBackground({super.key, required this.child});

  @override
  State<FloatingCurrencyBackground> createState() => _BackgroundState();
}

class _BackgroundState extends State<FloatingCurrencyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff0b1c2c), Color(0xff091422), Color(0xff12213b)],
          ),
        ),
      ),
      IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _motion,
              child: Image.asset(
                'assets/illustrations/floating_currency.png',
                fit: BoxFit.contain,
                cacheWidth: 768,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
              builder: (context, illustration) {
                final phase =
                    (_reducedMotion ? 0 : _motion.value) * math.pi * 2;
                return Stack(
                  children: [
                    Positioned(
                      right: -75,
                      top: -35,
                      width: 360,
                      height: 360,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(
                                0xff36d9bb,
                              ).withValues(alpha: .15 + .025 * math.sin(phase)),
                              const Color(0xff36d9bb).withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -20,
                      top: -2,
                      width: 218,
                      height: 218,
                      child: Transform.translate(
                        key: const Key('floatingCurrencyMotion'),
                        offset: Offset(
                          math.sin(phase) * 14,
                          math.cos(phase) * 12,
                        ),
                        child: Transform.rotate(
                          angle: math.sin(phase) * .045,
                          child: Opacity(opacity: .9, child: illustration),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -130,
                      bottom: 60,
                      width: 290,
                      height: 290,
                      child: Transform.translate(
                        offset: Offset(
                          math.cos(phase) * 20,
                          math.sin(phase) * 18,
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0x154d83ef), Color(0x004d83ef)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      // Keep a clear reading area on the left while the illustration floats right.
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x880b1c2c), Color(0x000b1c2c)],
              stops: [.05, .85],
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

/// A finite entrance transition; system reduced-motion preference is respected.
class RevealCard extends StatelessWidget {
  final Widget child;
  const RevealCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, content) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: content,
      ),
    ),
  );
}
