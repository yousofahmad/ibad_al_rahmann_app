import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../bloc/khatma_cubit.dart';
import '../data/khatma_model.dart';
import 'new_khatma_screen.dart';
import 'khatma_details_view.dart';
import 'khatma_details_screen.dart';

class WirdDashboardScreen extends StatefulWidget {
  const WirdDashboardScreen({super.key});

  @override
  State<WirdDashboardScreen> createState() => _WirdDashboardScreenState();
}

class _WirdDashboardScreenState extends State<WirdDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "الورد اليومي",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocBuilder<KhatmaCubit, KhatmaState>(
        builder: (context, state) {
          if (state is KhatmaLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A871)),
            );
          } else if (state is KhatmaEmpty) {
            return _buildEmptyState(context);
          } else if (state is KhatmaLoaded) {
            if (state.khatmas.isEmpty) return _buildEmptyState(context);
            if (state.khatmas.length == 1) {
              return KhatmaDetailsView(khatma: state.khatmas.first);
            } else {
              return _buildKhatmaList(context, state.khatmas, isDark);
            }
          } else if (state is KhatmaError) {
            return Center(
              child: Text(
                state.message,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BlocBuilder<KhatmaCubit, KhatmaState>(
        builder: (context, state) {
          if (state is KhatmaLoaded && state.khatmas.isNotEmpty) {
            if (state.khatmas.length == 1) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton.extended(
                    heroTag: "deleteBtn",
                    onPressed: () =>
                        _showDeleteDialog(context, state.khatmas.first.id),
                    backgroundColor: Colors.redAccent,
                    icon: const Icon(
                      FontAwesomeIcons.trashCan,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "حذف", // Changed label to "حذف" because button width could cause overflow on smaller screens
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  FloatingActionButton.extended(
                    heroTag: "addBtn",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NewKhatmaScreen(),
                        ),
                      );
                    },
                    backgroundColor: const Color(0xFFD0A871),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "ختمة جديدة",
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewKhatmaScreen()),
                  );
                },
                backgroundColor: const Color(0xFFD0A871),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "ختمة جديدة",
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.bookOpenReader,
            size: 80,
            color: Color(0xFFD0A871),
          ),
          const SizedBox(height: 20),
          Text(
            "لا توجد ختمة نشطة حالياً",
            style: TextStyle(
              fontSize: 22,
              fontFamily: AppConsts.expoArabic,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A871),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewKhatmaScreen()),
              );
            },
            child: const Text(
              "بدء ختمة جديدة",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKhatmaList(
    BuildContext context,
    List<KhatmaModel> khatmas,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
      itemCount: khatmas.length,
      itemBuilder: (context, index) {
        final khatma = khatmas[index];
        final progress =
            khatma.currentWirdIndex /
            (khatma.wirds.isNotEmpty ? khatma.wirds.length : 1);

        final delayedWirds = context.read<KhatmaCubit>().getDaysLate(khatma.id);
        final bool isLate = delayedWirds > 0;

        final cardColor = isLate
            ? (isDark
                ? Colors.red.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.05))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

        final borderColor = isLate
            ? Colors.red.withValues(alpha: 0.5)
            : const Color(0xFFD0A871).withValues(alpha: 0.5);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KhatmaDetailsScreen(khatmaId: khatma.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: borderColor, width: isLate ? 1.8 : 1.0),
                boxShadow: isDark || isLate
                    ? []
                    : [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          khatma.name.isNotEmpty
                              ? khatma.name
                              : "الختمة ${index + 1}",
                          style: const TextStyle(
                            color: Color(0xFFD0A871),
                            fontSize: 18,
                            fontFamily: AppConsts.expoArabic,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isLate)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "متأخر بمقدار $delayedWirds ورد",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppConsts.cairo,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFFD0A871),
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "عدد الأوراد المقروءة: ${khatma.currentWirdIndex} من أصل ${khatma.wirds.length}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? Colors.grey[800]
                          : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLate ? Colors.redAccent : const Color(0xFFD0A871),
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

  void _showDeleteDialog(BuildContext context, String khatmaId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "تنبيه",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontFamily: AppConsts.cairo,
          ),
        ),
        content: const Text(
          "هل أنت متأكد؟ سيتم حذف الختمة الحالية ولن تتمكن من استرجاعها.",
          style: TextStyle(fontFamily: AppConsts.cairo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<KhatmaCubit>().deleteKhatma(khatmaId);
            },
            child: const Text(
              "نعم، متأكد",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
