import 'package:hive_flutter/hive_flutter.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';

class BookmarkService {
  static const String _boxName = 'bookmarked_verses';
  static Box<VerseModel>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<VerseModel>(_boxName);
  }

  static Box<VerseModel> get box {
    if (_box == null) {
      throw Exception('BookmarkService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Add a verse to bookmarks
  static Future<void> addBookmark(VerseModel verse) async {
    await box.put(verse.uniqueKey, verse);
  }

  /// Remove a verse from bookmarks
  static Future<void> removeBookmark(VerseModel verse) async {
    await box.delete(verse.uniqueKey);
  }

  /// Remove a verse from bookmarks by surah and verse number
  static Future<void> removeBookmarkByVerse(
      int surahNumber, int verseNumber) async {
    final key = '${surahNumber}_$verseNumber';
    await box.delete(key);
  }

  /// Check if a verse is bookmarked
  static bool isBookmarked(VerseModel verse) {
    return box.containsKey(verse.uniqueKey);
  }

  /// Check if a verse is bookmarked by surah and verse number
  static bool isBookmarkedByVerse(int surahNumber, int verseNumber) {
    final key = '${surahNumber}_$verseNumber';
    return box.containsKey(key);
  }

  /// Get all bookmarked verses
  static List<VerseModel> getAllBookmarks() {
    return box.values.toList();
  }

  /// Get bookmarked verses sorted by bookmark date (newest first)
  static List<VerseModel> getBookmarksSortedByDate() {
    final bookmarks = getAllBookmarks();
    bookmarks.sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
    return bookmarks;
  }

  /// Get bookmarked verses for a specific surah
  static List<VerseModel> getBookmarksForSurah(int surahNumber) {
    return box.values
        .where((verse) => verse.surahNumber == surahNumber)
        .toList();
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    await box.clear();
  }

  /// Get bookmark count
  static int getBookmarkCount() {
    return box.length;
  }

  /// Toggle bookmark status for a verse
  static Future<bool> toggleBookmark(VerseModel verse) async {
    if (isBookmarked(verse)) {
      await removeBookmark(verse);
      return false; // Removed
    } else {
      await addBookmark(verse);
      return true; // Added
    }
  }
}
