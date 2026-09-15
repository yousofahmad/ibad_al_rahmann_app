import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../bloc/khatma_cubit.dart';
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

  Future<void> _showTimePickerDialog(BuildContext context, KhatmaCubit cubit, String? currentTime) async {
    final parts = (currentTime ?? '20:00').split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'وقت التنبيه اليومي',
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null) {
      final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await cubit.updateDailyTime(khatmaId, newTime);
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
                  final khatma = state.khatmas.firstWhere((k) => k.id == khatmaId);
                  if (khatma.notificationType == 'daily' && khatma.enableNotifications) {
                    return IconButton(
                      tooltip: 'تعديل وقت التنبيه',
                      onPressed: () => _showTimePickerDialog(
                        context,
                        context.read<KhatmaCubit>(),
                        khatma.dailyTime,
                      ),
                      icon: const Icon(Icons.access_time_rounded, color: Color(0xFFD0A871), size: 22),
                    );
                  }
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
      body: BlocBuilder<KhatmaCubit, KhatmaState>(
        builder: (context, state) {
          if (state is KhatmaLoaded) {
            try {
              final khatma = state.khatmas.firstWhere((k) => k.id == khatmaId);
              return KhatmaDetailsView(khatma: khatma);
            } catch (_) {
              return const Center(
                child: Text(
                  "هذه الختمة لم تعد موجودة",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
