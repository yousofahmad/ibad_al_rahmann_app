import 'package:flutter/material.dart';

import '../../../../../core/helpers/mushaf_format_repository.dart';
import 'optional_mushaf_page_widget.dart';
import 'wbw_page_widget.dart';

/// Selects the byte-preserved builtin renderer or the optional-format renderer.
class SelectedMushafPageWidget extends StatelessWidget {
  final int pageNumber;
  final bool isZoomEnabled;
  final int? startSuraNumber;
  final int? startAyah;
  final int? endSuraNumber;
  final int? endAyah;
  final bool showHeader;
  final bool showPageNumber;
  final Color? textColorOverride;
  final Color? paperColorOverride;
  final bool isSeamlessScroll;
  final bool collapseOutOfRange;
  final bool isLandscape;
  final VoidCallback? onPageLoaded;

  const SelectedMushafPageWidget({
    super.key,
    required this.pageNumber,
    this.isZoomEnabled = true,
    this.startSuraNumber,
    this.startAyah,
    this.endSuraNumber,
    this.endAyah,
    this.showHeader = true,
    this.showPageNumber = true,
    this.textColorOverride,
    this.paperColorOverride,
    this.isSeamlessScroll = false,
    this.collapseOutOfRange = false,
    this.isLandscape = false,
    this.onPageLoaded,
  });

  static bool useOptionalFormat([MushafFormatRepository? repository]) =>
      !(repository ?? MushafFormatRepository.instance).current.isBuiltin;

  /// Pure type decision used by tests without constructing a renderer or opening DBs.
  static Type widgetTypeForSelection(bool isBuiltin) =>
      isBuiltin ? WbwPageWidget : OptionalMushafPageWidget;

  Widget _page({required bool optional, required int revision}) {
    final key = optional
        ? ValueKey(
            'optional-${MushafFormatRepository.instance.current.id}-$revision',
          )
        : const ValueKey('builtin');
    final args = <String, dynamic>{
      'key': key,
      'pageNumber': pageNumber,
      'isZoomEnabled': isZoomEnabled,
      'startSuraNumber': startSuraNumber,
      'startAyah': startAyah,
      'endSuraNumber': endSuraNumber,
      'endAyah': endAyah,
      'showHeader': showHeader,
      'showPageNumber': showPageNumber,
      'textColorOverride': textColorOverride,
      'paperColorOverride': paperColorOverride,
      'isSeamlessScroll': isSeamlessScroll,
      'collapseOutOfRange': collapseOutOfRange,
      'isLandscape': isLandscape,
      'onPageLoaded': onPageLoaded,
    };
    return optional
        ? OptionalMushafPageWidget(
            key: args['key'] as Key?,
            pageNumber: pageNumber,
            isZoomEnabled: isZoomEnabled,
            startSuraNumber: startSuraNumber,
            startAyah: startAyah,
            endSuraNumber: endSuraNumber,
            endAyah: endAyah,
            showHeader: showHeader,
            showPageNumber: showPageNumber,
            textColorOverride: textColorOverride,
            paperColorOverride: paperColorOverride,
            isSeamlessScroll: isSeamlessScroll,
            collapseOutOfRange: collapseOutOfRange,
            isLandscape: isLandscape,
            onPageLoaded: onPageLoaded,
          )
        : WbwPageWidget(
            key: args['key'] as Key?,
            pageNumber: pageNumber,
            isZoomEnabled: isZoomEnabled,
            startSuraNumber: startSuraNumber,
            startAyah: startAyah,
            endSuraNumber: endSuraNumber,
            endAyah: endAyah,
            showHeader: showHeader,
            showPageNumber: showPageNumber,
            textColorOverride: textColorOverride,
            paperColorOverride: paperColorOverride,
            isSeamlessScroll: isSeamlessScroll,
            collapseOutOfRange: collapseOutOfRange,
            isLandscape: isLandscape,
            onPageLoaded: onPageLoaded,
          );
  }

  @override
  Widget build(BuildContext context) {
    final repository = MushafFormatRepository.instance;
    return ValueListenableBuilder<int>(
      valueListenable: repository.selectionRevision,
      builder: (_, revision, __) =>
          _page(optional: useOptionalFormat(repository), revision: revision),
    );
  }
}
