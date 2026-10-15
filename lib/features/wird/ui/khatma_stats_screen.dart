import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';
import '../bloc/khatma_cubit.dart';
import '../data/completed_khatma_model.dart';
import '../data/khatma_model.dart';
import 'khatm_quran_duaa_screen.dart';

class KhatmaStatsScreen extends StatefulWidget {
  const KhatmaStatsScreen({super.key});

  @override
  State<KhatmaStatsScreen> createState() => _KhatmaStatsScreenState();
}

class _KhatmaStatsScreenState extends State<KhatmaStatsScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  void _showManualCountDialog(BuildContext context, int currentCount) {
    final controller = TextEditingController(text: currentCount.toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "تعديل عدد الختمات السابقة",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
              color: const Color(0xFFD0A871),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "أدخل عدد الختمات التي أتممتها سابقاً خارج التطبيق ليتم احتسابها في إجمالي الختمات:",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 13.sp,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD0A871),
                ),
                decoration: InputDecoration(
                  labelText: "عدد الختمات السابقة",
                  labelStyle: const TextStyle(fontFamily: AppConsts.cairo),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFD0A871),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "إلغاء",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final newCount =
                    int.tryParse(
                      AppFormatters.toEnglishDigits(controller.text.trim()),
                    ) ??
                    currentCount;
                context.read<KhatmaCubit>().setManualCompletedCount(newCount);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text(
                "حفظ",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCompletedDialog(
    BuildContext context,
    CompletedKhatmaModel item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "حذف سجل الختمة",
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            "هل أنت متأكد من حذف سجل \"${item.name}\" من قائمة الختمات المكتملة؟",
            style: const TextStyle(fontFamily: AppConsts.cairo),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "إلغاء",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                context.read<KhatmaCubit>().deleteCompletedKhatma(item.id);
                Navigator.pop(ctx);
                setState(() {});
              },
              child: const Text(
                "حذف",
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<KhatmaCubit>();
    final completedList = cubit.getCompletedKhatmas();
    final manualCount = cubit.getManualCompletedCount();
    final totalCompleted = completedList.length + manualCount;

    // Calculate metrics
    int totalRecordedPages = 0;
    int totalRecordedWirds = 0;
    int fastestDays = 0;
    double avgDays = 0;

    if (completedList.isNotEmpty) {
      int totalDays = 0;
      fastestDays = completedList.first.actualDays;

      for (final k in completedList) {
        totalRecordedPages += k.pagesCount;
        totalRecordedWirds += k.totalWirds;
        totalDays += k.actualDays;
        if (k.actualDays < fastestDays && k.actualDays > 0) {
          fastestDays = k.actualDays;
        }
      }
      avgDays = totalDays / completedList.length;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF7F7F7);
    final cardBg = isDark ? const Color(0xFF141414) : Colors.white;

    // Active khatmas if any
    List<KhatmaModel> activeKhatmas = [];
    if (cubit.state is KhatmaLoaded) {
      activeKhatmas = (cubit.state as KhatmaLoaded).khatmas;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            "إحصائيات وسجل الختمات",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD0A871),
            ),
          ),
          actions: [
            IconButton(
              tooltip: "دعاء ختم القرآن",
              icon: const Icon(
                FontAwesomeIcons.bookOpen,
                color: Color(0xFFD0A871),
                size: 18,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KhatmQuranDuaaScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Trophy Banner
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2416), Color(0xFF1A140B)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70.w,
                      height: 70.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD0A871).withValues(alpha: 0.18),
                        border: Border.all(
                          color: const Color(0xFFD0A871),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.trophy,
                        color: Color(0xFFE8C58D),
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "إجمالي الختمات المكتملة",
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontSize: 13.sp,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$totalCompleted",
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF7D89C),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                totalCompleted == 1
                                    ? "ختمة مباركة"
                                    : totalCompleted == 2
                                    ? "ختمتان مباركتان"
                                    : "ختمات مباركة",
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD0A871),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Padding(
                            padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
                            child: Text(
                              "تقبل الله منا ومنكم صالح الأعمال",
                              style: TextStyle(
                                fontFamily: AppConsts.motoNastaliq,
                                fontSize: 13.5.sp,
                                color: Colors.white60,
                                height: 2.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 18.h),

              // 2. Metrics 4-Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: FontAwesomeIcons.bolt,
                      title: "أسرع ختمة",
                      value: fastestDays > 0 ? "$fastestDays يوم" : "—",
                      cardBg: cardBg,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildMetricCard(
                      icon: FontAwesomeIcons.clockRotateLeft,
                      title: "متوسط المدة",
                      value: avgDays > 0
                          ? "${avgDays.toStringAsFixed(0)} يوم"
                          : "—",
                      cardBg: cardBg,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: FontAwesomeIcons.bookQuran,
                      title: "صفحات مسجلة",
                      value: "$totalRecordedPages صفحة",
                      cardBg: cardBg,
                      isDark: isDark,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildMetricCard(
                      icon: FontAwesomeIcons.listCheck,
                      title: "أوراد منجزة",
                      value: "$totalRecordedWirds ورد",
                      cardBg: cardBg,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // 3. Manual Count Card (Previous Khatmas outside app)
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFD0A871).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        FontAwesomeIcons.circlePlus,
                        color: Color(0xFFD0A871),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ختمات سابقة خارج التطبيق",
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            "العدد المضاف: $manualCount ختمة",
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD0A871)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 6.h,
                        ),
                      ),
                      onPressed: () =>
                          _showManualCountDialog(context, manualCount),
                      child: Text(
                        "تعديل",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                          color: const Color(0xFFD0A871),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Active Khatmas (if any)
              if (activeKhatmas.isNotEmpty) ...[
                SizedBox(height: 22.h),
                Text(
                  "الختمات الجارية حالياً (${activeKhatmas.length})",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: const Color(0xFFD0A871),
                  ),
                ),
                SizedBox(height: 10.h),
                ...activeKhatmas.map((k) {
                  final progress = k.wirds.isNotEmpty
                      ? (k.currentWirdIndex / k.wirds.length)
                      : 0.0;
                  return Container(
                    margin: EdgeInsets.only(bottom: 10.h),
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              k.name,
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.sp,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              "${(progress * 100).toInt()}%",
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                                color: const Color(0xFFD0A871),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: isDark
                                ? Colors.white10
                                : Colors.black12,
                            color: const Color(0xFFD0A871),
                            minHeight: 6.h,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "الورد: ${k.currentWirdIndex + 1} من ${k.wirds.length}",
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              "بدأت: ${_dateFormat.format(k.startDate)}",
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                fontSize: 12.sp,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],

              SizedBox(height: 22.h),

              // 5. Completed Khatmas History Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "سجل الختمات المكتملة (${completedList.length})",
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: const Color(0xFFD0A871),
                    ),
                  ),
                  if (completedList.isNotEmpty)
                    Text(
                      "مرتبة من الأحدث",
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 11.sp,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10.h),

              if (completedList.isEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 30.h,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        FontAwesomeIcons.bookOpenReader,
                        size: 44,
                        color: Color(0xFFD0A871),
                      ),
                      SizedBox(height: 14.h),
                      Text(
                        "لم يتم تسجيل ختمة مكتملة بعد",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        "عند إتمامك لجميع أوراد أي ختمة جارية، ستتم أرشفتها هنا تلقائياً مع مدة الإنجاز وتاريخ الختم.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 12.sp,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: completedList.length,
                  itemBuilder: (context, index) {
                    final item = completedList[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD0A871).withValues(alpha: 0.3),
                        ),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
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
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      FontAwesomeIcons.circleCheck,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          fontFamily: AppConsts.expoArabic,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15.sp,
                                          color: const Color(0xFFD0A871),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: "حذف السجل",
                                icon: const Icon(
                                  FontAwesomeIcons.trashCan,
                                  size: 15,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    _showDeleteCompletedDialog(context, item),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoColumn(
                                "تاريخ البدء",
                                _dateFormat.format(item.startDate),
                              ),
                              _buildInfoColumn(
                                "تاريخ الختم",
                                _dateFormat.format(item.completedDate),
                              ),
                              _buildInfoColumn(
                                "المدة المستغرقة",
                                "${item.actualDays} يوم",
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "المخطط: ${item.daysPlanned} يوم • ${item.totalWirds} ورد",
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 11.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFD0A871,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.notificationType == 'prayer'
                                      ? "نظام الصلوات"
                                      : "نظام يومي",
                                  style: TextStyle(
                                    fontFamily: AppConsts.cairo,
                                    fontSize: 11.sp,
                                    color: const Color(0xFFD0A871),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              SizedBox(height: 24.h),

              // 6. Duaa Button CTA
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD0A871),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(FontAwesomeIcons.bookQuran, size: 18),
                label: Text(
                  "قراءة دعاء ختم القرآن الكريم",
                  style: TextStyle(
                    fontFamily: AppConsts.cairo,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KhatmQuranDuaaScreen(),
                    ),
                  );
                },
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color cardBg,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD0A871).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFD0A871)),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppConsts.cairo,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            fontSize: 11.sp,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppConsts.cairo,
            fontSize: 13.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFD0A871),
          ),
        ),
      ],
    );
  }
}

/// Helper function to show the celebration dialog when a Khatma is finished
Future<void> showKhatmaCompletionCelebrationDialog(
  BuildContext context, {
  required String khatmaName,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1B1812) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD0A871), width: 1.5),
        ),
        title: Column(
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD0A871).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFFD0A871), width: 2),
              ),
              child: const Icon(
                FontAwesomeIcons.trophy,
                color: Color(0xFFD0A871),
                size: 30,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              "🎉 هنيئاً لك ختم كتاب الله! 🎉",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
                color: const Color(0xFFD0A871),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "مبارك إتمامك لـ \"$khatmaName\"، نسأل الله أن يتقبل منك ويجعل القرآن العظيم ربيع قلبك ونور صدرك وشفيعاً لك يوم القيامة.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                fontSize: 13.sp,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "تم حفظ الختمة وإضافتها إلى سجل إحصائياتك.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                fontSize: 12.sp,
                color: const Color(0xFFD0A871),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowButtonSpacing: 8,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD0A871),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
            icon: const Icon(FontAwesomeIcons.bookQuran, size: 16),
            label: const Text(
              "قراءة دعاء ختم القرآن",
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KhatmQuranDuaaScreen()),
              );
            },
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD0A871)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            ),
            icon: const Icon(
              FontAwesomeIcons.chartPie,
              size: 16,
              color: Color(0xFFD0A871),
            ),
            label: const Text(
              "عرض الإحصائيات",
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                color: Color(0xFFD0A871),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const KhatmaStatsScreen()),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "إغلاق",
              style: TextStyle(fontFamily: AppConsts.cairo, color: Colors.grey),
            ),
          ),
        ],
      ),
    ),
  );
}
