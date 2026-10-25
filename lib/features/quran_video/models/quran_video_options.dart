import 'package:flutter/material.dart';

enum QuranVideoBackgroundType { image, video }

enum QuranVideoDisplayMode { ayahByAyah, wordHighlight, wordReveal }

enum QuranVideoAspectRatio { portrait, landscape, square }

enum QuranVideoResolution { hd720, fullHd1080 }

enum QuranVideoAudioKind { concatenatedVerses, fullSurah }

extension QuranVideoAspectRatioValues on QuranVideoAspectRatio {
  String get label => switch (this) {
    QuranVideoAspectRatio.portrait => 'عمودي 9:16',
    QuranVideoAspectRatio.landscape => 'أفقي 16:9',
    QuranVideoAspectRatio.square => 'مربع 1:1',
  };

  double get ratio => switch (this) {
    QuranVideoAspectRatio.portrait => 9 / 16,
    QuranVideoAspectRatio.landscape => 16 / 9,
    QuranVideoAspectRatio.square => 1,
  };

  (int, int) dimensions(QuranVideoResolution resolution) {
    final shortSide = switch (resolution) {
      QuranVideoResolution.hd720 => 720,
      QuranVideoResolution.fullHd1080 => 1080,
    };
    return switch (this) {
      QuranVideoAspectRatio.portrait => (shortSide, shortSide * 16 ~/ 9),
      QuranVideoAspectRatio.landscape => (shortSide * 16 ~/ 9, shortSide),
      QuranVideoAspectRatio.square => (shortSide, shortSide),
    };
  }
}

extension QuranVideoResolutionValues on QuranVideoResolution {
  String get label => switch (this) {
    QuranVideoResolution.hd720 => 'HD 720p — حجم أقل',
    QuranVideoResolution.fullHd1080 => 'Full HD 1080p — جودة أعلى',
  };

  int get videoBitrateKbps => switch (this) {
    QuranVideoResolution.hd720 => 2400,
    QuranVideoResolution.fullHd1080 => 4400,
  };
}

class QuranVideoExportOptions {
  const QuranVideoExportOptions({
    this.displayMode = QuranVideoDisplayMode.ayahByAyah,
    this.aspectRatio = QuranVideoAspectRatio.portrait,
    this.resolution = QuranVideoResolution.fullHd1080,
    this.fontSize = 48,
    this.textColor = Colors.white,
    this.highlightColor = const Color(0xFFFFD54F),
    this.position = 0.78,
    this.showTextPanel = true,
    this.panelOpacity = 0.58,
    this.showHighlight = true,
  });

  final QuranVideoDisplayMode displayMode;
  final QuranVideoAspectRatio aspectRatio;
  final QuranVideoResolution resolution;
  final int fontSize;
  final Color textColor;
  final Color highlightColor;

  /// Vertical placement as a fraction of the frame, from 0.18 to 0.86.
  final double position;
  final bool showTextPanel;
  final double panelOpacity;
  final bool showHighlight;

  int get width => aspectRatio.dimensions(resolution).$1;
  int get height => aspectRatio.dimensions(resolution).$2;
  int get videoBitrateKbps => resolution.videoBitrateKbps;

  QuranVideoExportOptions copyWith({
    QuranVideoDisplayMode? displayMode,
    QuranVideoAspectRatio? aspectRatio,
    QuranVideoResolution? resolution,
    int? fontSize,
    Color? textColor,
    Color? highlightColor,
    double? position,
    bool? showTextPanel,
    double? panelOpacity,
    bool? showHighlight,
  }) {
    return QuranVideoExportOptions(
      displayMode: displayMode ?? this.displayMode,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      resolution: resolution ?? this.resolution,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      highlightColor: highlightColor ?? this.highlightColor,
      position: position ?? this.position,
      showTextPanel: showTextPanel ?? this.showTextPanel,
      panelOpacity: panelOpacity ?? this.panelOpacity,
      showHighlight: showHighlight ?? this.showHighlight,
    );
  }
}
