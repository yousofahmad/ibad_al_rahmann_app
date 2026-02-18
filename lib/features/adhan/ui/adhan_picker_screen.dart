import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/adhan/models/muezzin_model.dart';
import 'package:ibad_al_rahmann/features/adhan/services/adhan_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdhanPickerScreen extends StatefulWidget {
  final String prefsKey; // e.g., 'adhan_sound_fajr'
  final String title;

  const AdhanPickerScreen({
    super.key,
    required this.prefsKey,
    required this.title,
  });

  @override
  State<AdhanPickerScreen> createState() => _AdhanPickerScreenState();
}

class _AdhanPickerScreenState extends State<AdhanPickerScreen>
    with SingleTickerProviderStateMixin {
  final AdhanManager _manager = AdhanManager();
  late TabController _tabController;
  List<String> _categories = [];
  String? _selectedPath;
  String? _playingId;
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _categories = _manager.getCategories();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPath = prefs.getString(widget.prefsKey);
    });
  }

  Future<void> _selectAdhan(Muezzin muezzin) async {
    // Only select if downloaded
    final path = await _manager.getLocalPath(muezzin.id);
    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى تحميل الأذان أولاً')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.prefsKey, path);
    setState(() {
      _selectedPath = path;
    });
  }

  Future<void> _download(Muezzin muezzin) async {
    setState(() {
      _downloadProgress[muezzin.id] = 0.0;
    });

    try {
      await _manager.downloadAdhan(muezzin, (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[muezzin.id] = progress;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("فشل التحميل: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(muezzin.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _manager.stopPreview();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFFD0A871),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFD0A871),
          labelStyle: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
          tabs: _categories
              .map((c) => Tab(text: _translateCategory(c)))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _categories.map((c) => _buildCategoryList(c)).toList(),
      ),
    );
  }

  String _translateCategory(String cat) {
    switch (cat) {
      case 'Egypt':
        return 'مصر';
      case 'Makkah':
        return 'مكة المكرمة';
      case 'Madina':
        return 'المدينة المنورة';
      case 'Al-Aqsa':
        return 'المسجد الأقصى';
      case 'Turkey':
        return 'تركيا';
      case 'Reciters':
        return 'أصوات مختلفة';
      default:
        return cat;
    }
  }

  Widget _buildCategoryList(String category) {
    final list = _manager.getByCategory(category);
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _buildMuezzinCard(list[index]);
      },
    );
  }

  Widget _buildMuezzinCard(Muezzin muezzin) {
    return FutureBuilder<bool>(
      future: _manager.isDownloaded(muezzin.id),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final isDownloading = _downloadProgress.containsKey(muezzin.id);

        return FutureBuilder<String?>(
          future: _manager.getLocalPath(muezzin.id),
          builder: (context, pathSnapshot) {
            final localPath = pathSnapshot.data;
            final isSelected =
                _selectedPath != null && _selectedPath == localPath;

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? const Color(0xFFD0A871) : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  // Play/Stop Preview
                  IconButton(
                    icon: Icon(
                      _playingId == muezzin.id
                          ? Icons.stop_circle
                          : Icons.play_circle_fill,
                      color: const Color(0xFFD0A871),
                      size: 32.sp,
                    ),
                    onPressed: () async {
                      if (_playingId == muezzin.id) {
                        await _manager.stopPreview();
                        setState(() => _playingId = null);
                      } else {
                        setState(() => _playingId = muezzin.id);
                        await _manager.playPreview(muezzin);
                      }
                    },
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          muezzin.name,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          muezzin.country,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: Colors.grey,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Button
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Color(0xFFD0A871))
                  else if (isDownloading)
                    SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: CircularProgressIndicator(
                        value: _downloadProgress[muezzin.id],
                        strokeWidth: 2,
                        color: const Color(0xFFD0A871),
                      ),
                    )
                  else if (isDownloaded)
                    TextButton(
                      onPressed: () => _selectAdhan(muezzin),
                      child: const Text(
                        "اختيار",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.cloud_download_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () => _download(muezzin),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
