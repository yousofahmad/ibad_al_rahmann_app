import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HisnMuslimScreen extends StatefulWidget {
  const HisnMuslimScreen({super.key});

  @override
  State<HisnMuslimScreen> createState() => _HisnMuslimScreenState();
}

class _HisnMuslimScreenState extends State<HisnMuslimScreen> {
  List<Map<String, dynamic>> _allChapters = [];
  List<String> _favoriteChapters = []; // List of titles
  bool _showFavoritesOnly = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load JSON and Favorites
  Future<void> _loadData() async {
    await Future.wait([_loadHisnData(), _loadFavorites()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadHisnData() async {
    try {
      String jsonString = await rootBundle.loadString('assets/data/hisn.json');
      Map<String, dynamic> jsonData = json.decode(jsonString);

      List<Map<String, dynamic>> temp = [];
      jsonData.forEach((key, value) {
        temp.add({
          "title": key,
          "text": List<String>.from(value['text']),
          "footnote": List<String>.from(value['footnote'] ?? []),
        });
      });
      _allChapters = temp;
    } catch (e) {
      debugPrint("Error loading Hisn data: $e");
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteChapters = prefs.getStringList('hisn_favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteChapters.contains(title)) {
        _favoriteChapters.remove(title);
      } else {
        _favoriteChapters.add(title);
      }
    });
    await prefs.setStringList('hisn_favorites', _favoriteChapters);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Filter list based on selection
    final displayedChapters = _showFavoritesOnly
        ? _allChapters
              .where((c) => _favoriteChapters.contains(c['title']))
              .toList()
        : _allChapters;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showFavoritesOnly ? 'المفضلة' : 'حصن المسلم',
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Toggle Favorites Button
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.list : Icons.favorite,
              color: const Color(0xFF3E2723),
            ),
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
            },
            tooltip: _showFavoritesOnly ? "عرض الكل" : "عرض المفضلة",
          ),
          const SizedBox(width: 10),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A871)),
            )
          : displayedChapters.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_remove_outlined,
                    size: 60,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _showFavoritesOnly
                        ? "لا توجد أدعية مفضلة"
                        : "لا توجد بيانات",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
              itemCount: displayedChapters.length,
              itemBuilder: (context, index) {
                final chapter = displayedChapters[index];
                final isFav = _favoriteChapters.contains(chapter['title']);

                return Card(
                  elevation: 2,
                  color: cardColor,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      chapter['title'],
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFFD0A871,
                      ).withValues(alpha: 0.1),
                      child: Text(
                        '${_allChapters.indexOf(chapter) + 1}', // Use original index
                        style: const TextStyle(
                          color: Color(0xFFD0A871),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Heart Icon to toggle favorite directly from list
                    trailing: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.grey.shade400,
                      ),
                      onPressed: () => _toggleFavorite(chapter['title']),
                    ),
                    onTap: () async {
                      // Wait for result in case user changes favorite status inside detail screen
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HisnDetailScreen(
                            title: chapter['title'],
                            texts: chapter['text'],
                            footnotes: chapter['footnote'],
                            isFavorite: isFav,
                            onFavoriteToggle: () =>
                                _toggleFavorite(chapter['title']),
                          ),
                        ),
                      );
                      // Refresh state to update list if changed inside detail
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// Detail Screen (Updated with Favorites)
// ==========================================
class HisnDetailScreen extends StatefulWidget {
  final String title;
  final List<String> texts;
  final List<String> footnotes;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const HisnDetailScreen({
    super.key,
    required this.title,
    required this.texts,
    required this.footnotes,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<HisnDetailScreen> createState() => _HisnDetailScreenState();
}

class _HisnDetailScreenState extends State<HisnDetailScreen> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFavorite;
  }

  void _toggle() {
    setState(() {
      _isFav = !_isFav;
    });
    widget.onFavoriteToggle(); // Update parent
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final footnoteColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final footnoteBgColor = isDark ? Colors.black26 : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : const Color(0xFF3E2723),
            ),
            onPressed: _toggle,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(15, 25, 15, 15),
        itemCount: widget.texts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 15),
        itemBuilder: (context, index) {
          String currentFootnote = "";
          if (index < widget.footnotes.length) {
            currentFootnote = widget.footnotes[index];
          }

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD0A871), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  widget.texts[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppConsts.amiri,
                    fontSize: 20,
                    height: 1.8,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (currentFootnote.isNotEmpty) ...[
                  Divider(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                    height: 30,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 15,
                    ),
                    decoration: BoxDecoration(
                      color: footnoteBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      currentFootnote,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 12,
                        color: footnoteColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 15),
                // Copy Button Only (Removed individual bookmark button)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.texts[index]));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم النسخ"),
                        duration: Duration(milliseconds: 500),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "نسخ",
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Color(0xFFD0A871),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.copy, size: 16, color: Color(0xFFD0A871)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
