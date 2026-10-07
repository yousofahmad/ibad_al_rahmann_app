import 'package:flutter/material.dart';

class ArabicSearchHelper {
  /// Strips Arabic diacritics (Tashkeel) from a given string.
  static String removeDiacritics(String text) {
    // Regex matches common Arabic diacritics (Fatha, Damma, Kasra, Sukun, Shadda, Tanween, etc.)
    return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  }

  /// Normalizes Arabic text for search (removes diacritics, normalizes Alef, Yaa, Taa Marbutah).
  static String normalizeArabic(String text) {
    String normalized = removeDiacritics(text);
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');
    return normalized;
  }

  /// Builds a list of TextSpans highlighting occurrences of [query] in [originalText].
  /// It ignores diacritics and Arabic letter variations (Alef, Yaa, Taa Marbutah) when finding matches,
  /// but preserves the original text's characters and diacritics in the output.
  static List<TextSpan> highlightMatch(
    String originalText,
    String query,
    TextStyle matchStyle, {
    TextStyle? baseStyle,
  }) {
    if (query.trim().isEmpty) {
      return [TextSpan(text: originalText, style: baseStyle)];
    }

    final normalizedText = normalizeArabic(originalText);
    final normalizedQuery = normalizeArabic(query);

    if (!normalizedText.contains(normalizedQuery)) {
      return [TextSpan(text: originalText, style: baseStyle)];
    }

    // Create a mapping from index in normalizedText to index in originalText
    List<int> mapping = [];
    for (int i = 0; i < originalText.length; i++) {
      if (!RegExp(r'[\u064B-\u065F\u0670]').hasMatch(originalText[i])) {
        mapping.add(i);
      }
    }
    // Add an end boundary
    mapping.add(originalText.length);

    List<TextSpan> spans = [];
    int currentIndex = 0; // Index in normalizedText
    int originalStartIndex = 0;

    while (true) {
      int matchIndex = normalizedText.indexOf(normalizedQuery, currentIndex);
      if (matchIndex == -1) {
        // No more matches, add the rest of the string
        if (originalStartIndex < originalText.length) {
          spans.add(
            TextSpan(
              text: originalText.substring(originalStartIndex),
              style: baseStyle,
            ),
          );
        }
        break;
      }

      // Add text before the match
      int originalMatchStart = mapping[matchIndex];
      if (originalMatchStart > originalStartIndex) {
        spans.add(
          TextSpan(
            text: originalText.substring(
              originalStartIndex,
              originalMatchStart,
            ),
            style: baseStyle,
          ),
        );
      }

      // Add the matched text
      int originalMatchEnd = mapping[matchIndex + normalizedQuery.length];
      spans.add(
        TextSpan(
          text: originalText.substring(originalMatchStart, originalMatchEnd),
          style: matchStyle,
        ),
      );

      currentIndex = matchIndex + normalizedQuery.length;
      originalStartIndex = originalMatchEnd;
    }

    return spans;
  }

  /// Extracts a relevant snippet surrounding the first match of [query] in [text],
  /// ignoring Arabic diacritics and letter variations.
  /// [contextChars] determines how many characters before and after to include.
  static String getSnippet(String text, String query, {int contextChars = 80}) {
    if (text.isEmpty) return '';
    if (query.trim().isEmpty) {
      return text.length > contextChars * 2
          ? '${text.substring(0, contextChars * 2)}...'
          : text;
    }

    final normalizedText = normalizeArabic(text);
    final normalizedQuery = normalizeArabic(query.trim());
    final matchIndex = normalizedText.indexOf(normalizedQuery);

    if (matchIndex == -1) {
      return text.length > contextChars * 2
          ? '${text.substring(0, contextChars * 2)}...'
          : text;
    }

    // Map normalized index back to original text
    List<int> mapping = [];
    for (int i = 0; i < text.length; i++) {
      if (!RegExp(r'[\u064B-\u065F\u0670]').hasMatch(text[i])) {
        mapping.add(i);
      }
    }
    mapping.add(text.length);

    int origStart = mapping[matchIndex];
    int origEnd =
        mapping[(matchIndex + normalizedQuery.length).clamp(
          0,
          mapping.length - 1,
        )];

    int snippetStart = (origStart - contextChars).clamp(0, text.length);
    int snippetEnd = (origEnd + contextChars).clamp(0, text.length);

    // Adjust snippet boundaries to word boundaries (space) if possible
    if (snippetStart > 0) {
      final spaceIndex = text.indexOf(' ', snippetStart);
      if (spaceIndex != -1 && spaceIndex < origStart) {
        snippetStart = spaceIndex + 1;
      }
    }
    if (snippetEnd < text.length) {
      final spaceIndex = text.lastIndexOf(' ', snippetEnd);
      if (spaceIndex != -1 && spaceIndex > origEnd) {
        snippetEnd = spaceIndex;
      }
    }

    String result = text.substring(snippetStart, snippetEnd).trim();
    if (snippetStart > 0) result = '...$result';
    if (snippetEnd < text.length) result = '$result...';

    return result;
  }
}
