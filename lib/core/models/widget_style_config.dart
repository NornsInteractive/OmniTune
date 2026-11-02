import 'package:flutter/foundation.dart';

@immutable
class WidgetStyleConfig {
  const WidgetStyleConfig({
    this.coverPosition = 'left',
    this.coverFill = true,
    this.coverOpacity = 0.5,
    this.backgroundColor = '#121620',
    this.themeColor = '#58A6FF',
    this.showLyrics = true,
  });

  final String coverPosition;
  final bool coverFill;
  final double coverOpacity;
  final String backgroundColor;
  final String themeColor;
  final bool showLyrics;

  WidgetStyleConfig copyWith({
    String? coverPosition,
    bool? coverFill,
    double? coverOpacity,
    String? backgroundColor,
    String? themeColor,
    bool? showLyrics,
  }) {
    return WidgetStyleConfig(
      coverPosition: coverPosition ?? this.coverPosition,
      coverFill: coverFill ?? this.coverFill,
      coverOpacity: (coverOpacity ?? this.coverOpacity).clamp(0.0, 1.0),
      backgroundColor: backgroundColor ?? this.backgroundColor,
      themeColor: themeColor ?? this.themeColor,
      showLyrics: showLyrics ?? this.showLyrics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coverPosition': coverPosition,
      'coverFill': coverFill,
      'coverOpacity': coverOpacity,
      'backgroundColor': backgroundColor,
      'themeColor': themeColor,
      'showLyrics': showLyrics,
    };
  }

  factory WidgetStyleConfig.fromJson(
    Map<String, dynamic>? json, {
    WidgetStyleConfig fallback = const WidgetStyleConfig(),
  }) {
    if (json == null) return fallback;
    return WidgetStyleConfig(
      coverPosition: (json['coverPosition'] as String?) ?? fallback.coverPosition,
      coverFill: (json['coverFill'] as bool?) ?? fallback.coverFill,
      coverOpacity: ((json['coverOpacity'] as num?)?.toDouble() ?? fallback.coverOpacity).clamp(0.0, 1.0),
      backgroundColor: (json['backgroundColor'] as String?) ?? fallback.backgroundColor,
      themeColor: (json['themeColor'] as String?) ?? fallback.themeColor,
      showLyrics: (json['showLyrics'] as bool?) ?? fallback.showLyrics,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetStyleConfig &&
          runtimeType == other.runtimeType &&
          coverPosition == other.coverPosition &&
          coverFill == other.coverFill &&
          (coverOpacity - other.coverOpacity).abs() < 0.001 &&
          backgroundColor == other.backgroundColor &&
          themeColor == other.themeColor &&
          showLyrics == other.showLyrics;

  @override
  int get hashCode => Object.hash(
        coverPosition,
        coverFill,
        coverOpacity.toStringAsFixed(2),
        backgroundColor,
        themeColor,
        showLyrics,
      );
}
