import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';

class MuezzinSelectionScreen extends StatefulWidget {
  final String? prefsKey; // If null, sets Global Default
  final String? title;

  const MuezzinSelectionScreen({super.key, this.prefsKey, this.title});

  @override
  State<MuezzinSelectionScreen> createState() => _MuezzinSelectionScreenState();
}

class _MuezzinSelectionScreenState extends State<MuezzinSelectionScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio();

  String? _selectedMuezzinId;
  String? _playingMuezzinId;
  String? _loadingMuezzinId; // For buffering state
  Map<String, double> _downloadProgress = {}; // ID -> Progress (0.0 - 1.0)
  Set<String> _downloadedIds = {}; // Local cached IDs

  late List<Map<String, dynamic>> _filteredData;
  String? _localPath;

  static const String _baseUrl =
      "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-sounds/main/";

  // --- THE DATA (Strictly as requested) ---
  final List<Map<String, dynamic>> muezzinData = [
    // 1. Famous Reciters (Egypt & Gulf)
    {
      "category": "قراء ومشاهير (مصر والخليج)",
      "muezzins": [
        {"name": "أحمد النفيس", "id": "nafis"}, // Added manually
        {"name": "مشاري راشد العفاسي (1)", "id": "mishary"},
        {"name": "مشاري راشد العفاسي (2)", "id": "mishary_2"},
        {"name": "عبد الباسط عبد الصمد (1)", "id": "abdulbasit"},
        {"name": "عبد الباسط عبد الصمد (2)", "id": "abdulbasit_2"},
        {"name": "عبد الباسط (العشاء)", "id": "abdulbasit_isha"},
        {"name": "عبد الباسط (القاهرة)", "id": "abdulbasit_cairo"},
        {"name": "محمد رفعت", "id": "rifat"},
        {"name": "محمود علي البنا", "id": "banna"},
        {"name": "مصطفى اسماعيل", "id": "mustafa_ismail"},
        {"name": "أبو العينين شعيشع", "id": "shaisha"},
        {"name": "محمود خليل الحصري", "id": "hussary"},
        {"name": "محمد صديق المنشاوي (1)", "id": "minshawi"},
        {"name": "محمد صديق المنشاوي (2)", "id": "minshawi_2"},
        {"name": "أحمد نعينع (القاهرة)", "id": "naina_cairo"},
        {"name": "السيد متولي العال", "id": "metwalli"},
        {"name": "أحمد نواف", "id": "nawaf"},
      ],
    },
    // 2. Haram Makki (Makkah)
    {
      "category": "مؤذني الحرم المكي",
      "muezzins": [
        {"name": "علي أحمد ملا (شيخ المؤذنين)", "id": "mulla"},
        {"name": "محمد رمل", "id": "raml"},
        {"name": "أذان مكة (16)", "id": "makkah_16"},
        {"name": "أذان مكة (19)", "id": "makkah_19"},
        {"name": "أذان مكة (20)", "id": "makkah_20"},
        {"name": "أذان مكة (قديم 1)", "id": "makkah_3"},
        {"name": "أذان مكة (قديم 2)", "id": "makkah_4"},
        {"name": "مهدي البيشي", "id": "bishi"},
        {"name": "عبد الرزاق صالح", "id": "saleh"},
      ],
    },
    // 3. Haram Madani (Madinah)
    {
      "category": "مؤذني الحرم المدني",
      "muezzins": [
        {"name": "أذان المدينة (18)", "id": "madinah_18"},
        {"name": "أذان المدينة (رئيسي)", "id": "madinah"},
        {"name": "أذان المدينة (2)", "id": "madinah_2"},
        {"name": "عبد المجيد السريحي", "id": "surayhi"}, // If file exists
      ],
    },
    // 4. International (Al-Aqsa & World)
    {
      "category": "المسجد الأقصى والعالم",
      "muezzins": [
        {"name": "أذان القدس", "id": "quds"},
        {"name": "ناجي قزاز (الأقصى 1)", "id": "aqsa_qazzaz"},
        {"name": "ناجي قزاز (الأقصى 2)", "id": "aqsa_qazzaz_2"},
        {"name": "تركيا (1)", "id": "turkey_1"},
        {"name": "تركيا (2)", "id": "turkey_2"},
        {"name": "حسين ايرك (تركيا)", "id": "duman"},
        {"name": "سوريا", "id": "syria"},
        {"name": "الجزائر", "id": "algeria"},
        {"name": "تونس", "id": "tunisia"},
        {"name": "الكويت", "id": "kuwait_3"},
        {"name": "دبي", "id": "dubai"},
        {"name": "مسقط (عمان)", "id": "oman"},
        {"name": "الهند", "id": "india"},
        {"name": "باكستان", "id": "pakistan"},
        {"name": "إندونيسيا", "id": "indonesia"},
        {"name": "ماليزيا", "id": "malaysia"},
        {"name": "بروني (1)", "id": "brunei_1"},
        {"name": "جزر المالديف", "id": "maldives"},
      ],
    },
    // 5. Fajr & Takbeerat
    {
      "category": "أذان الفجر وتكبيرات",
      "muezzins": [
        {"name": "تكبيرات العيد", "id": "takbeer_eid"},
        {"name": "أذان الفجر (مكة)", "id": "fajr_makkah"},
        {"name": "أذان الفجر (المدينة)", "id": "fajr_madinah"},
        {"name": "أذان الفجر (مصر)", "id": "fajr_egypt"},
        {"name": "أذان الفجر (القدس)", "id": "fajr_quds"},
        {"name": "أذان الفجر (الكويت)", "id": "fajr_kuwait_1"},
        {"name": "أذان الفجر (مشاري 1)", "id": "fajr_mishary_1"},
        {"name": "أذان الفجر (مشاري 2)", "id": "fajr_mishary_2"},
        {
          "name": "أذان الفجر (عبد الباسط)",
          "id": "fajr_abdulbasit",
        }, // If renamed from generic
      ],
    },
    // 6. Others (Generic)
    {
      "category": "مؤذني جامع الراجحي ومنوعات",
      "muezzins": [
        {"name": "جامع الراجحي (1)", "id": "rajhi"},
        {"name": "جامع الراجحي (2)", "id": "rajhi_2"},
        {"name": "حمزة الحلبية", "id": "halabiya"},
        {"name": "أحمد العمادي (قطر)", "id": "emadi"},
        {"name": "زهير طارش", "id": "taresh"},
        {"name": "عجمان", "id": "ajman"},
        {"name": "جورجيا", "id": "georgia"},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Initialize _filteredData immediately to avoid LateInitializationError
    _filteredData = List.from(muezzinData);
    _initValues();
  }

  Future<void> _initValues() async {
    final dir = await getApplicationSupportDirectory();
    final adhanDir = Directory("${dir.path}/adhans");
    if (!await adhanDir.exists()) {
      await adhanDir.create(recursive: true);
    }
    setState(() => _localPath = adhanDir.path);

    await _checkDownloads();
    await _loadSelection();
  }

  Future<void> _checkDownloads() async {
    if (_localPath == null) return;
    final Set<String> downloaded = {};

    // Check all muezzins
    for (var cat in muezzinData) {
      for (var m in (cat['muezzins'] as List)) {
        final id = m['id'];
        final file = File("$_localPath/$id.mp3");
        if (await file.exists()) {
          downloaded.add(id);
        }
      }
    }

    if (mounted) {
      setState(() => _downloadedIds = downloaded);
    }
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (widget.prefsKey != null) {
        // Load specific prayer sound
        _selectedMuezzinId = prefs.getString(widget.prefsKey!);
      } else {
        // Load global default
        _selectedMuezzinId = prefs.getString('adhan_muezzin_id') ?? 'mulla';
      }
    });
  }

  Future<void> _saveSelection(String id) async {
    // Optional: Force download if selecting?
    // For now, let's allow selecting even if not downloaded,
    // assuming native might have it baked in or user just wants the setting.
    // But logically, if it's "custom", it should be downloaded.
    if (!_downloadedIds.contains(id)) {
      // Auto-download on select?
      _downloadFile(id);
    }

    final prefs = await SharedPreferences.getInstance();

    if (widget.prefsKey != null) {
      // Specific Prayer Override
      await prefs.setString(widget.prefsKey!, id);
    } else {
      // Global Default
      await prefs.setString('adhan_muezzin_id', id);
      // Sync all prayers to this selection (Global Override)
      final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      for (var p in prayers) {
        await prefs.setString('adhan_sound_$p', id);
      }
    }

    setState(() => _selectedMuezzinId = id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "تم اختيار المؤذن (التنبيهات النظامية قد تستخدم الصوت الافتراضي إذا لم يكن مدمجًا)",
            style: TextStyle(fontFamily: AppConsts.cairo),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _downloadFile(String id) async {
    if (_localPath == null || _downloadProgress.containsKey(id)) return;

    setState(() => _downloadProgress[id] = 0.0);

    try {
      // CRITICAL FIX: Trim ID and use correct URL
      final url = "$_baseUrl${id.trim()}.mp3";
      final savePath = "$_localPath/$id.mp3";

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress[id] = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress.remove(id);
          _downloadedIds.add(id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("فشل التحميل: تأكد من الإنترنت")),
        );
      }
    }
  }

  Future<void> _playPreview(String id) async {
    if (_playingMuezzinId == id) {
      await _audioPlayer.stop();
      setState(() {
        _playingMuezzinId = null;
        _loadingMuezzinId = null;
      });
      return;
    }

    // Stop current
    await _audioPlayer.stop();

    // Check if local exists
    final isLocal = _downloadedIds.contains(id);

    setState(() {
      _playingMuezzinId = null;
      _loadingMuezzinId = id; // Buffering...
    });

    try {
      if (isLocal && _localPath != null) {
        final path = "$_localPath/$id.mp3";
        await _audioPlayer.play(DeviceFileSource(path));
      } else {
        // CRITICAL FIX: Trim ID and use correct URL for streaming
        final url = "$_baseUrl${id.trim()}.mp3";
        await _audioPlayer.play(UrlSource(url));
      }

      if (mounted) {
        setState(() {
          _loadingMuezzinId = null;
          _playingMuezzinId = id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMuezzinId = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("خطأ في التشغيل: $e")));
      }
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredData = List.from(muezzinData);
      } else {
        _filteredData = muezzinData
            .map((category) {
              final PLAYERS = (category['muezzins'] as List).where((m) {
                return (m['name'] as String).contains(query);
              }).toList();
              if (PLAYERS.isEmpty) return null;
              return {"category": category['category'], "muezzins": PLAYERS};
            })
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.title ?? "اختيار المؤذن",
          style: TextStyle(
            color: primaryColor,
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F5),
        iconTheme: IconThemeData(color: primaryColor),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontFamily: AppConsts.cairo,
              ),
              decoration: InputDecoration(
                hintText: "بحث عن مؤذن...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey[600],
                  fontFamily: AppConsts.cairo,
                ),
                prefixIcon: Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filter,
            ),
          ),

          // List
          Expanded(
            child: _localPath == null
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : CustomScrollView(
                    slivers: _filteredData.map((category) {
                      return SliverMainAxisGroup(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SectionHeaderDelegate(
                              category['category'],
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final muezzin = category['muezzins'][index];
                                final id = muezzin['id'];
                                final isSelected = _selectedMuezzinId == id;
                                final isPlaying = _playingMuezzinId == id;
                                final isLoading = _loadingMuezzinId == id;
                                final isDownloaded = _downloadedIds.contains(
                                  id,
                                );
                                final downloadProg = _downloadProgress[id];

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: primaryColor,
                                            width: 1,
                                          )
                                        : null,
                                    boxShadow: isDark
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: ListTile(
                                    onTap: () => _saveSelection(id),
                                    leading: GestureDetector(
                                      onTap: () => _playPreview(id),
                                      child: CircleAvatar(
                                        backgroundColor: primaryColor
                                            .withOpacity(0.15),
                                        child: isLoading
                                            ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: primaryColor,
                                                    ),
                                              )
                                            : Icon(
                                                isPlaying
                                                    ? Icons.stop
                                                    : Icons.play_arrow,
                                                color: primaryColor,
                                              ),
                                      ),
                                    ),
                                    title: Text(
                                      muezzin['name'],
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontFamily: AppConsts.expoArabic,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: isDownloaded
                                        ? const Text(
                                            "موجود على الجهاز",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                            ),
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Download Button / Status
                                        if (downloadProg != null)
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              value: downloadProg,
                                              color: primaryColor,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        else if (!isDownloaded)
                                          IconButton(
                                            icon: Icon(
                                              Icons.cloud_download_outlined,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () => _downloadFile(id),
                                          )
                                        else
                                          Icon(
                                            Icons.check,
                                            color: Colors.grey[600],
                                            size: 20,
                                          ),

                                        SizedBox(width: 8),

                                        // Selection Check
                                        if (isSelected)
                                          Icon(
                                            Icons.check_circle,
                                            color: primaryColor,
                                          )
                                        else
                                          Icon(
                                            Icons.radio_button_unchecked,
                                            color: isDark
                                                ? Colors.grey
                                                : Colors.grey[400],
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: (category['muezzins'] as List).length,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _SectionHeaderDelegate(this.title);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFD0A871);
    return Container(
      color: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5), // Background to cover
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: TextStyle(
          color: primaryColor,
          fontFamily: AppConsts.expoArabic,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  double get maxExtent => 50;

  @override
  double get minExtent => 50;

  @override
  bool shouldRebuild(covariant _SectionHeaderDelegate oldDelegate) {
    return oldDelegate.title != title;
  }
}
