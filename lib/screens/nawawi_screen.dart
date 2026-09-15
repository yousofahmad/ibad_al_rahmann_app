import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

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
  String _searchQuery = '';

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
    final prefs = CacheHelper.prefs;
    setState(() {
      _favoriteHadiths = prefs.getStringList('nawawi_favorites') ?? [];
    });
  }

  Future<void> _toggleFavorite(String title) async {
    final prefs = CacheHelper.prefs;
    setState(() {
      if (_favoriteHadiths.contains(title)) {
        _favoriteHadiths.remove(title);
      } else {
        _favoriteHadiths.add(title);
      }
    });
    await prefs.setStringList('nawawi_favorites', _favoriteHadiths);
  }

  /// Builds a RichText where every occurrence of [query] in [text] is
  /// highlighted with a gold background — identical to WhatsApp search style.
  Widget _buildHighlightedText(
    String text,
    String query, {
    TextStyle? baseStyle,
  }) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    int idx = lower.indexOf(lowerQ);
    while (idx != -1) {
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx), style: baseStyle));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: (baseStyle ?? const TextStyle()).copyWith(
          backgroundColor: const Color(0xFFFFE082),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
      idx = lower.indexOf(lowerQ, start);
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return RichText(
      textDirection: TextDirection.rtl,
      text: TextSpan(children: spans),
    );
  }

  /// Returns a ~120-char snippet of [hadith] centred around the first match
  /// of [query], with "..." on either side when truncated.
  String _hadithSnippet(String hadith, String query) {
    final lower = hadith.toLowerCase();
    final idx = lower.indexOf(query.toLowerCase());
    if (idx == -1) return hadith.length > 120 ? '${hadith.substring(0, 120)}...' : hadith;
    const half = 60;
    final from = (idx - half).clamp(0, hadith.length);
    final to = (idx + query.length + half).clamp(0, hadith.length);
    final prefix = from > 0 ? '...' : '';
    final suffix = to < hadith.length ? '...' : '';
    return '$prefix${hadith.substring(from, to)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final snippetColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;

    final baseHadiths = _showFavoritesOnly
        ? _allHadiths
              .where((h) => _favoriteHadiths.contains(h['title']))
              .toList()
        : List<Map<String, dynamic>>.from(_allHadiths);

    final displayedHadiths = _searchQuery.isEmpty
        ? baseHadiths
        : baseHadiths
              .where(
                (h) =>
                    (h['title'] as String? ?? '').contains(_searchQuery) ||
                    (h['hadith'] as String? ?? '').contains(_searchQuery),
              )
              .toList();

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
          SizedBox(width: 10.w),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
          ),
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: EdgeInsets.all(10.w),
              itemCount: 8,
              itemBuilder: (_, __) => AppSkeleton.indexItem(),
            )
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
                  child: TextField(
                    textDirection: TextDirection.rtl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'ابحث في الأحاديث...',
                      hintStyle: TextStyle(fontFamily: AppConsts.expoArabic, fontSize: 13.sp),
                      hintTextDirection: TextDirection.rtl,
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFD0A871)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Color(0xFFD0A871)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: const BorderSide(color: Color(0xFFD0A871), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.r),
                        borderSide: BorderSide(color: const Color(0xFFD0A871).withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: displayedHadiths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_remove_outlined,
                    size: 60.w,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 10.h),
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
              padding: EdgeInsets.fromLTRB(10.w, 20.h, 10.w, 10.h),
              itemCount: displayedHadiths.length,
              itemBuilder: (context, index) {
                final hadith = displayedHadiths[index];
                final isFav = _favoriteHadiths.contains(hadith['title']);

                return Card(
                  elevation: 2,
                  color: cardColor,
                  margin: EdgeInsets.symmetric(vertical: 6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    side: BorderSide(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      width: 1.w,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      hadith['title'],
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 16.sp,
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
                ), // Expanded
              ],
            ), // Column
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
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final descBgColor = isDark ? Colors.black26 : Colors.grey.shade50;
    final descTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF3E2723),
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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF2D69D), Color(0xFFD0A871), Color(0xFFB88A4A)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30.r)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(15.w),
        child: Column(
          children: [
            // Hadith Text Card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFD0A871), width: 1.5.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10.r,
                    offset: Offset(0, 5.h),
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
                      fontSize: 20.sp,
                      height: 1.8,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 15.h),
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
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "نسخ الحديث",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: const Color(0xFFD0A871),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Icon(Icons.copy, size: 16.w, color: const Color(0xFFD0A871)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Description / Sharh
            if (widget.description.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15.w),
                decoration: BoxDecoration(
                  color: descBgColor,
                  borderRadius: BorderRadius.circular(15.r),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "شرح وفوائد",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD0A871),
                      ),
                    ),
                    const Divider(color: Color(0xFFD0A871), thickness: 0.5),
                    SizedBox(height: 5.h),
                    Text(
                      widget.description,
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14.sp,
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
