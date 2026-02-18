import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';

import 'bookmark_item.dart';

class BookmarksList extends StatelessWidget {
  final List<VerseModel> bookmarks;
  final Function(VerseModel) onNavigateToVerse;
  final Function(VerseModel) onPlayVerse;
  final Function(VerseModel) onRemoveBookmark;

  const BookmarksList({
    super.key,
    required this.bookmarks,
    required this.onNavigateToVerse,
    required this.onPlayVerse,
    required this.onRemoveBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final verse = bookmarks[index];
        return BookmarkItem(
          verse: verse,
          onTap: () => onNavigateToVerse(verse),
          
        );
      },
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.greyYellow),
    );
  }
}
