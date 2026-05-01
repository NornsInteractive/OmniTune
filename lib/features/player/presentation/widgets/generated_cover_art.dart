import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/studio_chrome.dart';

class GeneratedCoverArt extends StatelessWidget {
  const GeneratedCoverArt({
    super.key,
    required this.title,
    required this.subtitle,
    this.size = 220,
    this.borderRadius = 32,
    this.clipBorderRadius,
    this.showFrame = true,
  });

  final String title;
  final String subtitle;
  final double size;
  final double borderRadius;
  final BorderRadiusGeometry? clipBorderRadius;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveBorderRadius = clipBorderRadius != null
        ? studioBorderRadiusOf(context, clipBorderRadius!)
        : BorderRadius.circular(studioRadiusOf(context, borderRadius));
    final initials = _initials(title);
    final compact = size < 150;
    final micro = size < 110;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
            colorScheme.surfaceContainerHighest,
          ],
        ),
        border: Border.all(
          color: showFrame
              ? colorScheme.outlineVariant.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        boxShadow: showFrame
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Stack(
          children: [
            Positioned(
              right: -size * 0.12,
              top: -size * 0.06,
              child: Container(
                width: size * 0.52,
                height: size * 0.52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface.withValues(alpha: 0.2),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _StripePainter(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: micro
                  ? Center(
                      child: Text(
                        initials,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: size * 0.28,
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.34,
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            size: compact ? size * 0.14 : size * 0.1,
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          initials,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: compact ? size * 0.2 : size * 0.18,
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.24,
                            ),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: compact ? size * 0.01 : size * 0.02),
                        Text(
                          title,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: compact ? size * 0.12 : null,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!compact) ...[
                          SizedBox(height: size * 0.02),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.82,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'FM';
    }
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final spacing = math.max(20, size.width * 0.12);
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
