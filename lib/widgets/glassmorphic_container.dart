import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15.0),
      child: kIsWeb
          ? Container(
              margin: const EdgeInsets.only(right: 10, bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: child,
            )
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.only(right: 10, bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: child,
              ),
            ),
    );
  }
}
