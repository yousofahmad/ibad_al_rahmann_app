import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/share_cards/models/share_card_model.dart';
import 'package:ibad_al_rahmann/features/share_cards/services/share_cards_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ShareCardsScreen extends StatefulWidget {
  const ShareCardsScreen({super.key});

  @override
  State<ShareCardsScreen> createState() => _ShareCardsScreenState();
}

class _ShareCardsScreenState extends State<ShareCardsScreen> {
  final ShareCardsService _service = ShareCardsService();
  List<ShareCardCategory> _categories = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _service.fetchShareCards();
    if (mounted) {
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadAndShare(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/share_image.jpg";
      await Dio().download(url, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تجهيز الصورة للمشاركة ✓',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Color(0xFFD0A871),
          ),
        );
      }
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'من تطبيق عباد الرحمن');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في مشاركة الصورة')),
        );
      }
    }
  }

  Future<void> _saveToGallery(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = "${tempDir.path}/temp_save.jpg";
      await Dio().download(url, path);
      await Gal.putImage(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ الصورة في المعرض بنجاح ✓',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Color(0xFFD0A871),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل في حفظ الصورة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "بطاقات المشاركة",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: gold,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _categories.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildCategoryTabs(),
                    Expanded(child: _buildCardsGrid()),
                  ],
                ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategoryIndex = index),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD0A871) : Colors.transparent,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFFD0A871), width: 1.w),
              ),
              child: Text(
                _categories[index].categoryName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: isSelected ? Colors.white : const Color(0xFFD0A871),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardsGrid() {
    final items = _categories[_selectedCategoryIndex].items;
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final fullUrl = _service.getFullImageUrl(item.url);
        return _buildCardItem(item, fullUrl);
      },
    );
  }

  Widget _buildCardItem(ShareCardItem item, String url) {
    const gold = Color(0xFFD0A871);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: gold, size: 20),
                  onPressed: () => _downloadAndShare(url),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt_rounded, color: gold, size: 20),
                  onPressed: () => _saveToGallery(url),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        color: const Color(0xFFD0A871),
        strokeWidth: 3.w,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          const Text(
            "لا توجد بطاقات متاحة حالياً",
            style: TextStyle(fontFamily: 'Cairo', color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
