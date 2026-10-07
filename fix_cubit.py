
# -*- coding: utf-8 -*-
import re

with open("lib/features/quran/bloc/verse_player/verse_player_cubit.dart", "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(r"Future<void> playNextVerse\(\) async \{.*?await initVerse\(autoPlay: true\);\s*\}", re.DOTALL)

replacement = """bool _isChangingVerse = false;

  Future<void> playNextVerse() async {
    if (_isChangingVerse) return;
    if (currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      final totalVersesInSurah = getVerseCount(currnetVerse!.surahNumber);
      int nextSNum = currnetVerse!.surahNumber;
      int nextVNum = currnetVerse!.verseNumber + 1;
      if (nextVNum > totalVersesInSurah) {
        if (nextSNum < 114) {
          nextSNum += 1;
          nextVNum = 1;
        } else {
          AppLogger.log("VersePlayer", "Reached end of Quran (Surah 114)");
          return;
        }
      }
      final nextText = getVerse(nextSNum, nextVNum);
      final nextPg = getPageNumber(nextSNum, nextVNum);
      final nextFont = \"page\$nextPg\";

      AppLogger.log(
        "VersePlayer",
        "Advancing to next verse: \$nextSNum:\$nextVNum (page \$nextPg)",
      );

      setVerse(
        surahNumber: nextSNum,
        verseNumber: nextVNum,
        fontFamily: nextFont,
        verse: nextText,
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
  }"""

content = pattern.sub(replacement, content)

pattern2 = re.compile(r"Future<void> playPreviousVerse\(\) async \{.*?await initVerse\(autoPlay: true\);\s*\}", re.DOTALL)

replacement2 = """Future<void> playPreviousVerse() async {
    if (_isChangingVerse) return;
    if (currnetVerse == null) return;
    _isChangingVerse = true;
    try {
      int prevSNum = currnetVerse!.surahNumber;
      int prevVNum = currnetVerse!.verseNumber - 1;
      if (prevVNum < 1) {
        if (prevSNum > 1) {
          prevSNum -= 1;
          prevVNum = getVerseCount(prevSNum);
        } else {
          AppLogger.log("VersePlayer", "Reached beginning of Quran (Surah 1)");
          return;
        }
      }
      final prevText = getVerse(prevSNum, prevVNum);
      final prevPg = getPageNumber(prevSNum, prevVNum);
      final prevFont = \"page\$prevPg\";

      AppLogger.log(
        "VersePlayer",
        "Going back to previous verse: \$prevSNum:\$prevVNum (page \$prevPg)",
      );

      setVerse(
        surahNumber: prevSNum,
        verseNumber: prevVNum,
        fontFamily: prevFont,
        verse: prevText,
      );
      await initVerse(autoPlay: true);
    } finally {
      _isChangingVerse = false;
    }
  }"""

content = pattern2.sub(replacement2, content)

with open("lib/features/quran/bloc/verse_player/verse_player_cubit.dart", "w", encoding="utf-8") as f:
    f.write(content)

