import 'package:ibad_al_rahmann/features/wird/data/khatma_model.dart';
import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/app_formatters.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../bloc/khatma_cubit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'khatma_details_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class KhatmaDetailsScreen extends StatelessWidget {
  final String khatmaId;

  const KhatmaDetailsScreen({super.key, required this.khatmaId});

  void _showDeleteWarningDialog(BuildContext context) {
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
          "هل أنت متأكد؟ سيتم حذف هذه الختمة ولن تتمكن من استرجاعها.",
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
              Navigator.pop(context);
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

  Future<void> _showPrayerOffsetsDialog(
    BuildContext context,
    KhatmaCubit cubit,
    KhatmaModel khatma,
  ) async {
    final map =
        khatma.notificationOffsetMinutesMap ??
        {
          'الفجر': khatma.notificationOffsetMinutes,
          'الظهر': khatma.notificationOffsetMinutes,
          'العصر': khatma.notificationOffsetMinutes,
          'المغرب': khatma.notificationOffsetMinutes,
          'العشاء': khatma.notificationOffsetMinutes,
        };
    final fajrCtrl = TextEditingController(
      text: (map['الفجر'] ?? 30).toString(),
    );
    final dhuhrCtrl = TextEditingController(
      text: (map['الظهر'] ?? 30).toString(),
    );
    final asrCtrl = TextEditingController(
      text: (map['العصر'] ?? 30).toString(),
    );
    final maghribCtrl = TextEditingController(
      text: (map['المغرب'] ?? 30).toString(),
    );
    final ishaCtrl = TextEditingController(
      text: (map['العشاء'] ?? 30).toString(),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            'تعديل دقائق التأخير',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOffsetField('الفجر', fajrCtrl, isDark),
                const SizedBox(height: 10),
                _buildOffsetField('الظهر', dhuhrCtrl, isDark),
                const SizedBox(height: 10),
                _buildOffsetField('العصر', asrCtrl, isDark),
                const SizedBox(height: 10),
                _buildOffsetField('المغرب', maghribCtrl, isDark),
                const SizedBox(height: 10),
                _buildOffsetField('العشاء', ishaCtrl, isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'الفجر':
                      int.tryParse(
                        AppFormatters.toEnglishDigits(fajrCtrl.text),
                      ) ??
                      30,
                  'الظهر':
                      int.tryParse(
                        AppFormatters.toEnglishDigits(dhuhrCtrl.text),
                      ) ??
                      30,
                  'العصر':
                      int.tryParse(
                        AppFormatters.toEnglishDigits(asrCtrl.text),
                      ) ??
                      30,
                  'المغرب':
                      int.tryParse(
                        AppFormatters.toEnglishDigits(maghribCtrl.text),
                      ) ??
                      30,
                  'العشاء':
                      int.tryParse(
                        AppFormatters.toEnglishDigits(ishaCtrl.text),
                      ) ??
                      30,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD0A871),
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await cubit.updatePrayerOffsets(khatma.id, result);
    }
  }

  Widget _buildOffsetField(
    String label,
    TextEditingController ctrl,
    bool isDark,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              suffixText: 'دقيقة',
              suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimePickerDialog(
    BuildContext context,
    KhatmaCubit cubit,
    String? currentTime,
  ) async {
    final parts = (currentTime ?? '20:00').split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'وقت التنبيه اليومي',
      builder: (ctx, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) {
      final newTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await cubit.updateDailyTime(khatmaId, newTime);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم ضبط وقت التنبيه اليومي على الساعة $newTime بنجاح',
              style: const TextStyle(fontFamily: AppConsts.cairo),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showStartDatePickerDialog(
    BuildContext context,
    KhatmaCubit cubit,
    DateTime currentStartDate,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentStartDate,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'تعديل تاريخ بدء الختمة',
      builder: (ctx, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFFD0A871),
                onPrimary: Colors.black,
              ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      await cubit.updateKhatmaStartDate(khatmaId, picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم تعديل تاريخ بدء الختمة وتحديث جدول التأخير بنجاح',
              style: TextStyle(fontFamily: AppConsts.cairo),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          "تفاصيل الختمة",
          style: TextStyle(
            color: Color(0xFFD0A871),
            fontFamily: AppConsts.expoArabic,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        actions: [
          BlocBuilder<KhatmaCubit, KhatmaState>(
            builder: (context, state) {
              if (state is KhatmaLoaded) {
                try {
                  final khatma = state.khatmas.firstWhere(
                    (k) => k.id == khatmaId,
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تعديل تاريخ بدء الختمة',
                        icon: const Icon(FontAwesomeIcons.calendarDay, size: 18),
                        onPressed: () => _showStartDatePickerDialog(
                          context,
                          context.read<KhatmaCubit>(),
                          khatma.startDate,
                        ),
                      ),
                      IconButton(
                        tooltip: 'تعديل وقت التنبيه',
                        icon: const Icon(FontAwesomeIcons.clock, size: 18),
                        onPressed: () {
                          if (khatma.notificationType == 'prayer') {
                            _showPrayerOffsetsDialog(
                              context,
                              context.read<KhatmaCubit>(),
                              khatma,
                            );
                          } else {
                            _showTimePickerDialog(
                              context,
                              context.read<KhatmaCubit>(),
                              khatma.dailyTime,
                            );
                          }
                        },
                      ),
                    ],
                  );
                } catch (_) {}
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            onPressed: () => _showDeleteWarningDialog(context),
            icon: const Icon(
              FontAwesomeIcons.trashCan,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('appDataBox').listenable(),
        builder: (context, box, _) {
          return BlocConsumer<KhatmaCubit, KhatmaState>(
            listener: (context, state) {
              if (state is KhatmaEmpty) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } else if (state is KhatmaLoaded) {
                final exists = state.khatmas.any((k) => k.id == khatmaId);
                if (!exists && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              }
            },
            builder: (context, state) {
              if (state is KhatmaLoaded) {
                try {
                  final khatma = state.khatmas.firstWhere(
                    (k) => k.id == khatmaId,
                  );
                  return KhatmaDetailsView(khatma: khatma);
                } catch (_) {
                  return const SizedBox.shrink();
                }
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
