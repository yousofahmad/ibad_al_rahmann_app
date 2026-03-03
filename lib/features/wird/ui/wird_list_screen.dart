import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../../../../main.dart';
import '../bloc/khatma_cubit.dart';
import 'isolated_wird_screen.dart';

class WirdListScreen extends StatelessWidget {
  final bool showPrevious;

  const WirdListScreen({super.key, required this.showPrevious});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          showPrevious ? "الأوراد السابقة" : "الأوراد القادمة",
          style: const TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
      ),
      body: BlocBuilder<KhatmaCubit, KhatmaState>(
        builder: (context, state) {
          if (state is KhatmaLoaded) {
            final khatma = state.khatma;
            final currentIndex = khatma.currentWirdIndex;

            // Filter
            final wirds = showPrevious
                ? khatma.wirds.sublist(0, currentIndex)
                : khatma.wirds.sublist(currentIndex + 1);

            if (wirds.isEmpty) {
              return Center(
                child: Text(
                  showPrevious
                      ? "لا توجد أوراد سابقة بعد"
                      : "لا توجد أوراد قادمة",
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: wirds.length,
              itemBuilder: (context, index) {
                final wird = wirds[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: InkWell(
                    onTap: () {
                      navigatorKey.currentState!.push(
                        MaterialPageRoute(
                          builder: (_) => IsolatedWirdScreen(
                            wirdIndex: wird.wirdIndex,
                            targetStartPage: wird.startPage,
                            targetEndPage: wird.endPage,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: wird.isCompleted
                              ? Colors.green.withValues(alpha: 0.5)
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: wird.isCompleted ? 2 : 1,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "الورد ${wird.wirdIndex + 1}",
                                style: const TextStyle(
                                  color: Color(0xFFD0A871),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (wird.isCompleted)
                                const Icon(
                                  FontAwesomeIcons.circleCheck,
                                  color: Colors.green,
                                  size: 20,
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                "من:",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "سورة ${wird.startSurahName} - آية ${wird.startAyah}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Text(
                                "إلى:",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "سورة ${wird.endSurahName} - آية ${wird.endAyah}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFD0A871,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "صفحة ${wird.startPage} إلى ${wird.endPage}",
                              style: const TextStyle(
                                color: Color(0xFFD0A871),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
