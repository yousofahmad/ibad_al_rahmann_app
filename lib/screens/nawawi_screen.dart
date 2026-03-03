import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NawawiScreen extends StatefulWidget {
  const NawawiScreen({super.key});

  @override
  State<NawawiScreen> createState() => _NawawiScreenState();
}

class _NawawiScreenState extends State<NawawiScreen> {
  List<String> _favoriteHadiths = [];
  bool _showFavoritesOnly = false;
  List<Map<String, dynamic>> _allHadiths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadNawawiData(), _loadFavorites()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadNawawiData() async {
    try {
      String jsonString = await rootBundle.loadString(
        'assets/data/nawawi.json',
      );
      List<dynamic> jsonData = json.decode(jsonString);

      List<Map<String, dynamic>> temp = [];
      for (var item in jsonData) {
        temp.add({
          "title": item['title'],
          "hadith": item['hadith'],
          "description": item['description'],
        });
      }
      _allHadiths = temp;
    } catch (e) {
      debugPrint("Error loading Nawawi data: $e");
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteHadiths = prefs.getStringList('nawawi_favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteHadiths.contains(title)) {
        _favoriteHadiths.remove(title);
      } else {
        _favoriteHadiths.add(title);
      }
    });
    await prefs.setStringList('nawawi_favorites', _favoriteHadiths);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final displayedHadiths = _showFavoritesOnly
        ? _allHadiths
              .where((h) => _favoriteHadiths.contains(h['title']))
              .toList()
        : _allHadiths;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showFavoritesOnly ? 'المفضلة' : 'الأربعين النووية',
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
          : displayedHadiths.isEmpty
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
                        ? "لا توجد أحاديث مفضلة"
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
              itemCount: displayedHadiths.length,
              itemBuilder: (context, index) {
                final hadith = displayedHadiths[index];
                final isFav = _favoriteHadiths.contains(hadith['title']);

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
                      hadith['title'],
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
                        '${_allHadiths.indexOf(hadith) + 1}',
                        style: const TextStyle(
                          color: Color(0xFFD0A871),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.grey.shade400,
                      ),
                      onPressed: () => _toggleFavorite(hadith['title']),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NawawiDetailScreen(
                            title: hadith['title'],
                            hadithText: hadith['hadith'],
                            description: hadith['description'],
                            isFavorite: isFav,
                            onFavoriteToggle: () =>
                                _toggleFavorite(hadith['title']),
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}

class NawawiDetailScreen extends StatefulWidget {
  final String title;
  final String hadithText;
  final String description;

  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const NawawiDetailScreen({
    super.key,
    required this.title,
    required this.hadithText,
    required this.description,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  State<NawawiDetailScreen> createState() => _NawawiDetailScreenState();
}

class _NawawiDetailScreenState extends State<NawawiDetailScreen> {
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
    widget.onFavoriteToggle();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final descBgColor = isDark ? Colors.black26 : Colors.grey.shade50;
    final descTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 16,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Hadith Text Card
            Container(
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
                    widget.hadithText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppConsts.amiri,
                      fontSize: 20,
                      height: 1.8,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Copy Button
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: "${widget.title}\n\n${widget.hadithText}",
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم نسخ الحديث"),
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
                            "نسخ الحديث",
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
            ),
            const SizedBox(height: 20),

            // Description / Sharh
            if (widget.description.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: descBgColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "شرح وفوائد",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD0A871),
                      ),
                    ),
                    const Divider(color: Color(0xFFD0A871), thickness: 0.5),
                    const SizedBox(height: 5),
                    Text(
                      widget.description,
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14,
                        height: 1.6,
                        color: descTextColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
