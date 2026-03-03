import 'package:flutter/material.dart';
import '../data/quran_db_helper.dart';
import 'layouts/mobile_quran_top_bar.dart';
import 'layouts/mobile_min_quran_bottom_section.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Quran pages go from 1 to 604, but PageView uses 0-indexed.
    // Starting at 0 (Page 1) or any preferred index.
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xfffffdf5,
      ), // Traditional Mushaf paper color
      body: SafeArea(
        child: Column(
          children: [
            const MobileQuranTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                // 604 pages in the standard Mushaf
                itemCount: 604,
                // Arabic reads Right-to-Left, so pages should flip accordingly
                reverse: true,
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: QuranDbHelper.instance.getPageLines(pageNumber),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading page: \${snapshot.error}'),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('No lines found for this page.'),
                        );
                      }

                      final lines = snapshot.data!;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: lines.map((lineData) {
                            final String text = lineData['line_text'] as String;
                            final int isCentered =
                                lineData['is_centered'] as int? ?? 0;
                            final String lineType =
                                lineData['line_type'] as String? ?? 'ayah';

                            // Handle Surah/Juz headers if they are centered
                            if (isCentered == 1 ||
                                lineType == 'surah_name' ||
                                lineType == 'basmalah') {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Text(
                                  text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'UthmanicHafs',
                                    fontSize: 24, // Adjust for headers
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            }

                            final isPage1Or2 =
                                pageNumber == 1 || pageNumber == 2;

                            // Render exactly one justified line using FittedBox
                            return Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: (isCentered == 1 || isPage1Or2)
                                      ? null
                                      : 1000,
                                  child: RichText(
                                    textDirection: TextDirection.rtl,
                                    textAlign: (isCentered == 1 || isPage1Or2)
                                        ? TextAlign.center
                                        : TextAlign.justify,
                                    text: TextSpan(
                                      text: text,
                                      style: const TextStyle(
                                        fontFamily: 'UthmanicHafs',
                                        fontSize:
                                            40, // Base large size to downscale smoothly
                                        height: 1.5,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const MobileMinQuranBottomSection(),
          ],
        ),
      ),
    );
  }
}
