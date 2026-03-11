import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/daily_tracker_service.dart';

class ZekrData {
  final String text;
  final int count;
  final String category;
  final String source;
  final String sound;
  ZekrData({
    required this.text,
    required this.count,
    required this.category,
    required this.source,
    required this.sound,
  });
  factory ZekrData.fromJson(Map<String, dynamic> json) {
    return ZekrData(
      text: json['zekr'] ?? "",
      count: int.tryParse(json['count'].toString()) ?? 1,
      category: json['description'] ?? "",
      source: json['source'] ?? "",
      sound: json['sound'] ?? "",
    );
  }
}

class AzkarPage extends StatefulWidget {
  final String title;
  final String jsonFile;
  final String image;
  const AzkarPage({
    super.key,
    required this.title,
    required this.jsonFile,
    required this.image,
  });
  @override
  State<AzkarPage> createState() => _AzkarPageState();
}

class _AzkarPageState extends State<AzkarPage> {
  final PageController _pageController = PageController();
  final AudioPlayer _player = AudioPlayer();

  List<ZekrData> _azkarList = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _currentCount = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  double _fontSize = 22.0; // حجم الخط الافتراضي
  bool _vibrationEnabled = true;
  final Color _goldColor = const Color(0xFFD0A871);
  int _streakCount = 0;
  List<int> _currentCounts = [];

  @override
  void initState() {
    super.initState();
    _loadProgressAndData();
    _loadSettings();
    _setupAudioListeners();
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _loadProgressAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final keyIndex = 'azkar_progress_${widget.jsonFile}';
    final savedIndex = prefs.getInt(keyIndex) ?? 0;

    await _loadData();

    if (mounted && _azkarList.isNotEmpty) {
      final keyCounts = 'azkar_counts_${widget.jsonFile}';
      final savedCountsStr = prefs.getString(keyCounts);
      if (savedCountsStr != null) {
        try {
          List<dynamic> decoded = json.decode(savedCountsStr);
          _currentCounts = decoded.map((e) => e as int).toList();
        } catch (_) {}
      }
      if (_currentCounts.length != _azkarList.length) {
        _currentCounts = List.filled(_azkarList.length, 0);
      }

      setState(() {
        _currentIndex = savedIndex < _azkarList.length ? savedIndex : 0;
        _currentCount = _currentCounts[_currentIndex];
      });
      // Jump to saved page after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
  }

  Future<void> _saveProgress(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final keyIndex = 'azkar_progress_${widget.jsonFile}';
    final keyCounts = 'azkar_counts_${widget.jsonFile}';
    await prefs.setInt(keyIndex, index);

    if (_currentCounts.isNotEmpty && _currentIndex < _currentCounts.length) {
      _currentCounts[_currentIndex] = _currentCount;
      await prefs.setString(keyCounts, json.encode(_currentCounts));
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrationEnabled = prefs.getBool('vibrate_azkar') ?? true;
    });
    // Load Streak
    String key = _getCategoryKey();
    if (key.isNotEmpty) {
      await DailyTrackerService.markAsStarted(key);
      final streak = await DailyTrackerService.getStreak(key);
      if (mounted) setState(() => _streakCount = streak);
    }
  }

  void _setupAudioListeners() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _player.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _player.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      debugPrint("AzkarPage: Loading assets/data/${widget.jsonFile}");
      final String response = await rootBundle.loadString(
        'assets/data/${widget.jsonFile}',
      );
      debugPrint("AzkarPage: Loaded ${response.length} chars");
      final List<dynamic> data = json.decode(response);
      debugPrint("AzkarPage: Parsed ${data.length} items");
      setState(() {
        _azkarList = data.map((item) => ZekrData.fromJson(item)).toList();
        _isLoading = false;
      });
    } catch (e, s) {
      debugPrint("AzkarPage: ERROR loading ${widget.jsonFile}: $e");
      debugPrint("AzkarPage: STACK: $s");
      setState(() => _isLoading = false);
    }
  }

  void _toggleAudio() async {
    if (_azkarList.isEmpty) return;
    String soundFile = _azkarList[_currentIndex].sound;
    if (soundFile.isEmpty) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.setPlaybackRate(_playbackSpeed);
      await _player.play(AssetSource('audio/$soundFile'));
    }
  }

  Future<void> _seekAudio(int seconds) async {
    if (_duration == Duration.zero) return;

    Duration newPosition = _position + Duration(seconds: seconds);
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > _duration) newPosition = _duration;

    await _player.seek(newPosition);
  }

  void _changeSpeed() {
    setState(() {
      _playbackSpeed = (_playbackSpeed == 1.0)
          ? 1.5
          : (_playbackSpeed == 1.5 ? 2.0 : 1.0);
      _player.setPlaybackRate(_playbackSpeed);
    });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showSourceDialog(String source) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border.all(
              color: _goldColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _goldColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: _goldColor,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "تخريج الحديث",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _goldColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: _goldColor.withValues(alpha: 0.15), height: 1),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                  child: Text(
                    source,
                    style: TextStyle(
                      fontFamily: AppConsts.amiri,
                      fontSize: _fontSize,
                      height: 1.8,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              // Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _goldColor.withValues(alpha: 0.1),
                      foregroundColor: _goldColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "إغلاق",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _goldColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fix: Handle empty list or loading state safer
    if (_azkarList.isEmpty && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            "لا توجد أذكار متاحة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Safety check for index
    if (_currentIndex >= _azkarList.length) {
      _currentIndex = 0;
    }

    bool hasSound =
        !_isLoading &&
        _azkarList.isNotEmpty &&
        _azkarList[_currentIndex].sound.isNotEmpty;
    // Dark mode check just for container background logic if needed,
    // though we use black/white explicitly in some places.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Settings Icon
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$_streakCount",
                    style: const TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_fontSize < 40) _fontSize += 2;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_fontSize > 14) _fontSize -= 2;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(widget.image),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: _goldColor))
              : Column(
                  children: [
                    // مسافة علوية ديناميكية عشان نراعي الـ Notch والـ Header
                    SizedBox(height: MediaQuery.of(context).padding.top + 60),
                    LinearProgressIndicator(
                      value: (_currentIndex + 1) / _azkarList.length,
                      backgroundColor: Colors.white30,
                      color: _goldColor,
                      minHeight: 4,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _azkarList.length,
                        onPageChanged: (index) {
                          _player.stop();
                          _saveProgress(index);
                          setState(() {
                            _currentIndex = index;
                            _currentCount = _currentCounts[index];
                            _isPlaying = false;
                            _position = Duration.zero;
                            _duration = Duration.zero;
                          });
                        },
                        itemBuilder: (context, index) =>
                            _buildZekrCard(_azkarList[index]),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        bool isLastItemMaxed =
                            _currentIndex == _azkarList.length - 1 &&
                            _currentCount == _azkarList[_currentIndex].count;
                        bool isCompletedAll = false;

                        if (isLastItemMaxed) {
                          isCompletedAll = _currentCounts.asMap().entries.every(
                            (e) => e.value >= _azkarList[e.key].count,
                          );
                        }

                        if (isCompletedAll) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: ElevatedButton.icon(
                              onPressed: _finishAzkarSession,
                              icon: const Icon(Icons.home, color: Colors.white),
                              label: const Text(
                                "العودة للصفحة الرئيسية",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD0A871),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          );
                        } else if (isLastItemMaxed && !isCompletedAll) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                int incompleteIdx = _currentCounts
                                    .asMap()
                                    .entries
                                    .firstWhere(
                                      (e) => e.value < _azkarList[e.key].count,
                                    )
                                    .key;
                                _pageController.animateToPage(
                                  incompleteIdx,
                                  duration: const Duration(milliseconds: 600),
                                  curve: Curves.easeInOut,
                                );
                              },
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "إكمال الأذكار المتبقية",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[800],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          );
                        }

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_currentCount <
                                  _azkarList[_currentIndex].count) {
                                _currentCount++;
                                _currentCounts[_currentIndex] = _currentCount;
                              }

                              _saveProgress(_currentIndex);

                              if (_vibrationEnabled) {
                                NotificationService.vibrate(duration: 70);
                              }

                              if (_currentCount ==
                                      _azkarList[_currentIndex].count &&
                                  _currentIndex < _azkarList.length - 1) {
                                if (_vibrationEnabled) {
                                  NotificationService.vibrate(duration: 500);
                                }
                                Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOut,
                                  ),
                                );
                              } else if (_currentCount ==
                                      _azkarList[_currentIndex].count &&
                                  _currentIndex == _azkarList.length - 1) {
                                if (_vibrationEnabled) {
                                  NotificationService.vibrate(duration: 500);
                                }
                              }
                            });
                          },
                          child: Container(
                            width: 90,
                            height: 90,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: _goldColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: Center(
                              child: Text(
                                "${_azkarList[_currentIndex].count - _currentCount}",
                                style: TextStyle(
                                  fontFamily: AppConsts.expoArabic,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(1, 1),
                                      blurRadius: 2,
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (hasSound)
                      SafeArea(
                        top: false,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white)
                                .withValues(alpha: 0.95),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(25),
                            ),
                            border: Border(
                              top: BorderSide(
                                color: _goldColor.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              left: BorderSide(
                                color: _goldColor.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              right: BorderSide(
                                color: _goldColor.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                spreadRadius: 2,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "الاستماع للذكر",
                                      style: TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _changeSpeed,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: _goldColor),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          "${_playbackSpeed}x",
                                          style: TextStyle(
                                            fontFamily: AppConsts.expoArabic,
                                            color: _goldColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    trackHeight: 2,
                                    thumbColor: _goldColor,
                                    activeTrackColor: _goldColor,
                                    inactiveTrackColor: Colors.grey.shade700,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: _duration.inSeconds.toDouble() > 0
                                        ? _duration.inSeconds.toDouble()
                                        : 1.0,
                                    value: _position.inSeconds.toDouble().clamp(
                                      0,
                                      _duration.inSeconds.toDouble(),
                                    ),
                                    onChanged: (value) {
                                      _player.seek(
                                        Duration(seconds: value.toInt()),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatTime(_position),
                                      style: const TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.replay_10,
                                            color: Colors.grey,
                                            size: 24,
                                          ),
                                          onPressed: () => _seekAudio(-10),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: _toggleAudio,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _goldColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.forward_10,
                                            color: Colors.grey,
                                            size: 24,
                                          ),
                                          onPressed: () => _seekAudio(10),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _formatTime(_duration),
                                      style: const TextStyle(
                                        fontFamily: AppConsts.expoArabic,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildZekrCard(ZekrData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      // إزالة SingleChildScrollView الخارجي لضمان ثبات الكارت في المنتصف واحترام القيود
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Container(
          constraints: BoxConstraints(
            // أقصى ارتفاع للكارت 70% من الشاشة عشان يسيب مسافة فوق وتحت
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: 0.95,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: _goldColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // الكارت ينكمش لو الكلام قليل
            children: [
              if (data.category.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _goldColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(23),
                      topRight: Radius.circular(23),
                    ),
                  ),
                  child: Text(
                    data.category,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      color: _goldColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              Flexible(
                fit: FlexFit.loose, // يسمح للنص يكون أصغر من المساحة المتاحة
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    data.text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: AppConsts.amiri,
                      fontSize: _fontSize,
                      height: 1.8,
                      color: (isDark ? Colors.white : const Color(0xFF2D2D2D)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Divider(color: _goldColor.withValues(alpha: 0.2), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.copy, color: _goldColor, size: 26),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: data.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("تم النسخ"),
                                duration: Duration(milliseconds: 500),
                              ),
                            );
                          },
                        ),
                        if (data.source.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.info_outline,
                              color: _goldColor,
                              size: 26,
                            ),
                            onPressed: () => _showSourceDialog(data.source),
                          ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _goldColor,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "التكرار: ${data.count}",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.share, color: _goldColor, size: 26),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: data.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishAzkarSession() async {
    String key = _getCategoryKey();

    if (key.isNotEmpty) {
      await DailyTrackerService.markAsDone(key);
      final newStreak = await DailyTrackerService.getStreak(key);
      if (mounted) {
        setState(() => _streakCount = newStreak);
      }
    }

    // Suggest leaving or show completion
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "تقبل الله! تم تسجيل الإنجاز ✅",
            style: TextStyle(fontFamily: AppConsts.expoArabic),
          ),
          backgroundColor: _goldColor,
        ),
      );
      // Check mounted again before navigation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  String _getCategoryKey() {
    if (widget.title.contains('الصباح')) return 'morning_azkar';
    if (widget.title.contains('المساء')) return 'evening_azkar';
    if (widget.title.contains('الصلاة')) return 'prayer_azkar';
    return '';
  }
}
