import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';
import 'package:url_launcher/url_launcher.dart';

class FiqhScreen extends StatefulWidget {
  const FiqhScreen({super.key});

  @override
  State<FiqhScreen> createState() => _FiqhScreenState();
}

class _FiqhScreenState extends State<FiqhScreen> {
  List<dynamic> _questions = [];
  List<dynamic> _filteredQuestions = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final String response = await rootBundle.loadString('assets/data/fiqh_questions.json');
      final data = await json.decode(response);
      setState(() {
        _questions = data;
        _filteredQuestions = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterQuestions(String query) {
    setState(() {
      _filteredQuestions = _questions
          .where((q) =>
              q['question'].toString().toLowerCase().contains(query.toLowerCase()) ||
              q['answer'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);

    if (_isLoading) {
      return ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: 8,
        itemBuilder: (_, __) => AppSkeleton.card(height: 80.h),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              onChanged: _filterQuestions,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: "بحث في الفتاوى...",
                hintStyle: const TextStyle(fontFamily: AppConsts.expoArabic),
                prefixIcon: const Icon(Icons.search, color: goldColor),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final q = _filteredQuestions[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.r),
                    side: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                  ),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: goldColor.withAlpha(30),
                      child: Text(
                        q['id'].toString(),
                        style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      q['question'],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          q['answer'],
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            fontSize: 13.sp,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: _filteredQuestions.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "المرئيات",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: goldColor,
                  ),
                ),
                SizedBox(height: 12.h),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('https://youtube.com/playlist?list=PL1i_D1Vw3d5P5Q6IHHW22JHrnLCwm60Bn')),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [goldColor, Color(0xFFB8860B)],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: goldColor.withAlpha(50),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "سلسلة فقه الصيام",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "تعلم أحكام الصيام بطريقة ميسرة",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 12.sp,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
