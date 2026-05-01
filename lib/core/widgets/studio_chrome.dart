import 'dart:ui';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../storage/background_image_store.dart';

@immutable
class StudioThemeData extends ThemeExtension<StudioThemeData> {
  const StudioThemeData({
    this.compactness = 1,
    this.backgroundImageSource,
    this.backgroundImageAlignment = Alignment.center,
  });

  final double compactness;
  final String? backgroundImageSource;
  final Alignment backgroundImageAlignment;

  @override
  StudioThemeData copyWith({
    double? compactness,
    String? backgroundImageSource,
    Alignment? backgroundImageAlignment,
  }) {
    return StudioThemeData(
      compactness: compactness ?? this.compactness,
      backgroundImageSource:
          backgroundImageSource ?? this.backgroundImageSource,
      backgroundImageAlignment:
          backgroundImageAlignment ?? this.backgroundImageAlignment,
    );
  }

  @override
  StudioThemeData lerp(ThemeExtension<StudioThemeData>? other, double t) {
    if (other is! StudioThemeData) {
      return this;
    }

    return StudioThemeData(
      compactness: compactness + (other.compactness - compactness) * t,
      backgroundImageSource: t < 0.5
          ? backgroundImageSource
          : other.backgroundImageSource,
      backgroundImageAlignment:
          Alignment.lerp(
            backgroundImageAlignment,
            other.backgroundImageAlignment,
            t,
          ) ??
          backgroundImageAlignment,
    );
  }
}

class StudioBackdrop extends StatelessWidget {
  const StudioBackdrop({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxContentWidth,
    this.showBackgroundImage = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxContentWidth;
  final bool showBackgroundImage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final contentWidth = maxContentWidth ?? width;
        final studioTheme = Theme.of(context).extension<StudioThemeData>();
        final backgroundImageSource = studioTheme?.backgroundImageSource;

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    _GlacierPalette.background,
                    _GlacierPalette.surface,
                    _GlacierPalette.background,
                  ],
                ),
              ),
            ),
            if (showBackgroundImage &&
                backgroundImageSource != null &&
                backgroundImageSource.isNotEmpty)
              Positioned.fill(
                child: _StudioBackgroundImage(
                  source: backgroundImageSource,
                  alignment:
                      studioTheme?.backgroundImageAlignment ?? Alignment.center,
                ),
              ),
            Positioned(
              left: -width * 0.15,
              top: -140,
              child: _BackdropGlow(
                size: math.max(280, width * 0.56),
                color: _GlacierPalette.primary.withValues(alpha: 0.24),
              ),
            ),
            Positioned(
              right: -width * 0.12,
              top: 120,
              child: _BackdropGlow(
                size: math.max(220, width * 0.42),
                color: _GlacierPalette.tertiary.withValues(alpha: 0.18),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _GlacierPalette.background.withValues(alpha: 0.08),
                        _GlacierPalette.background.withValues(alpha: 0),
                        _GlacierPalette.background.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: studioPaddingOf(context, padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudioPanel extends StatelessWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.tint,
    this.alignment = Alignment.topLeft,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final surface = tint ?? _GlacierPalette.surface;
    final effectiveRadius = studioRadiusOf(context, radius);
    final effectivePadding = studioPaddingOf(context, padding);

    return ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: _GlacierPalette.primary.withValues(alpha: 0.12),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Align(
            alignment: alignment,
            child: Padding(padding: effectivePadding, child: child),
          ),
        ),
      ),
    );
  }
}

EdgeInsets studioPaddingOf(BuildContext context, EdgeInsetsGeometry padding) {
  final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  final resolved = padding.resolve(textDirection);
  final compactness = studioCompactnessOf(context);

  return EdgeInsets.fromLTRB(
    resolved.left * compactness,
    resolved.top * compactness,
    resolved.right * compactness,
    resolved.bottom * compactness,
  );
}

double studioCompactnessOf(BuildContext context) {
  return (Theme.of(context).extension<StudioThemeData>()?.compactness ?? 0.5)
      .clamp(0.5, 1.5)
      .toDouble();
}

double studioSpacingOf(BuildContext context, double value) {
  return value * studioCompactnessOf(context);
}

double studioListScaleOf(BuildContext context) {
  final compactness = studioCompactnessOf(context);
  return (0.7 + (compactness - 0.5) * 0.6).clamp(0.7, 1.3).toDouble();
}

double studioListSpacingOf(BuildContext context, double value) {
  return value * studioListScaleOf(context);
}

EdgeInsets studioListPaddingOf(
  BuildContext context,
  EdgeInsetsGeometry padding,
) {
  final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  final resolved = padding.resolve(textDirection);
  final scale = studioListScaleOf(context);

  return EdgeInsets.fromLTRB(
    resolved.left * scale,
    resolved.top * scale,
    resolved.right * scale,
    resolved.bottom * scale,
  );
}

double studioListGapOf(BuildContext context) {
  return studioListSpacingOf(context, 10).clamp(9.0, 13.0).toDouble();
}

double studioListIconBoxSizeOf(BuildContext context) {
  return studioListSpacingOf(context, 40).clamp(36.0, 44.0).toDouble();
}

double studioListActionSizeOf(BuildContext context) {
  return studioListSpacingOf(context, 36).clamp(32.0, 42.0).toDouble();
}

EdgeInsets studioListItemPaddingOf(BuildContext context) {
  return studioListPaddingOf(
    context,
    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );
}

double studioRadiusOf(BuildContext context, double radius) {
  if (radius >= 900) {
    return radius;
  }

  var configuredRadius = 28.0;
  final shape = Theme.of(context).cardTheme.shape;
  if (shape is RoundedRectangleBorder) {
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    configuredRadius = shape.borderRadius.resolve(textDirection).topLeft.x;
  }

  return (configuredRadius * radius / 28).clamp(4.0, 56.0).toDouble();
}

class _StudioBackgroundImage extends StatefulWidget {
  const _StudioBackgroundImage({required this.source, required this.alignment});

  final String source;
  final Alignment alignment;

  @override
  State<_StudioBackgroundImage> createState() => _StudioBackgroundImageState();
}

class _StudioBackgroundImageState extends State<_StudioBackgroundImage> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = readStudioBackgroundImage(widget.source);
  }

  @override
  void didUpdateWidget(_StudioBackgroundImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _bytesFuture = readStudioBackgroundImage(widget.source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: widget.alignment,
              filterQuality: FilterQuality.medium,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.58),
                    colorScheme.surface.withValues(alpha: 0.72),
                    colorScheme.surface.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StudioGap extends StatelessWidget {
  const StudioGap({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width == null ? null : studioSpacingOf(context, width!),
      height: height == null ? null : studioSpacingOf(context, height!),
    );
  }
}

class StudioSliverGap extends StatelessWidget {
  const StudioSliverGap({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: StudioGap(height: height));
  }
}

class StudioPill extends StatelessWidget {
  const StudioPill({
    super.key,
    required this.label,
    this.icon,
    this.prominent = false,
  });

  final String label;
  final IconData? icon;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = prominent
        ? _GlacierPalette.primary.withValues(alpha: 0.12)
        : _GlacierPalette.surfaceContainerHighest.withValues(alpha: 0.78);
    final foreground = prominent
        ? _GlacierPalette.primary
        : _GlacierPalette.onSurfaceVariant;

    return Container(
      padding: studioPaddingOf(
        context,
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _GlacierPalette.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            StudioGap(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class StudioSectionTitle extends StatelessWidget {
  const StudioSectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.description,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                Text(
                  eyebrow!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _GlacierPalette.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const StudioGap(height: 6),
              ],
              Text(title, style: theme.textTheme.headlineSmall),
              if (description != null && description!.isNotEmpty) ...[
                const StudioGap(height: 6),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _GlacierPalette.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const StudioGap(width: 16),
          Flexible(child: trailing!),
        ],
      ],
    );
  }
}

class StudioStatBlock extends StatelessWidget {
  const StudioStatBlock({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: studioPaddingOf(context, const EdgeInsets.all(16)),
      decoration: BoxDecoration(
        color: _GlacierPalette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _GlacierPalette.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _GlacierPalette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 18, color: _GlacierPalette.primary),
            ),
            const StudioGap(width: 10),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const StudioGap(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _GlacierPalette.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlacierPalette {
  static const background = Color(0xFF0A0E1A);
  static const surface = Color(0xFF0F1524);
  static const surfaceContainerHighest = Color(0xFF202C42);
  static const primary = Color(0xFF7DD3FC);
  static const tertiary = Color(0xFFC8A0F0);
  static const onSurfaceVariant = Color(0xFFA0B4C4);
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.08),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
