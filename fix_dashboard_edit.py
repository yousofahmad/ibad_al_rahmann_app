import re

with open('lib/features/wird/ui/wird_dashboard_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

dialogs = '''
  Future<void> _showPrayerOffsetsDialog(BuildContext context, KhatmaCubit cubit, KhatmaModel khatma) async {
    final map = khatma.notificationOffsetMinutesMap ?? {
      'الفجر': khatma.notificationOffsetMinutes,
      'الظهر': khatma.notificationOffsetMinutes,
      'العصر': khatma.notificationOffsetMinutes,
      'المغرب': khatma.notificationOffsetMinutes,
      'العشاء': khatma.notificationOffsetMinutes,
    };
    final fajrCtrl = TextEditingController(text: (map['الفجر'] ?? 30).toString());
    final dhuhrCtrl = TextEditingController(text: (map['الظهر'] ?? 30).toString());
    final asrCtrl = TextEditingController(text: (map['العصر'] ?? 30).toString());
    final maghribCtrl = TextEditingController(text: (map['المغرب'] ?? 30).toString());
    final ishaCtrl = TextEditingController(text: (map['العشاء'] ?? 30).toString());

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            'تعديل دقائق التأخير',
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
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
                  'الفجر': int.tryParse(fajrCtrl.text) ?? 30,
                  'الظهر': int.tryParse(dhuhrCtrl.text) ?? 30,
                  'العصر': int.tryParse(asrCtrl.text) ?? 30,
                  'المغرب': int.tryParse(maghribCtrl.text) ?? 30,
                  'العشاء': int.tryParse(ishaCtrl.text) ?? 30,
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

  Widget _buildOffsetField(String label, TextEditingController ctrl, bool isDark) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              suffixText: 'دقيقة',
              suffixStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimePickerDialog(BuildContext context, KhatmaCubit cubit, String? currentTime, String khatmaId) async {
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
      final newTime = ':';
      await cubit.updateDailyTime(khatmaId, newTime);
    }
  }
'''

content = content.replace('class _WirdDashboardScreenState extends State<WirdDashboardScreen> {', 'class _WirdDashboardScreenState extends State<WirdDashboardScreen> {\n' + dialogs)

app_bar = '''        appBar: AppBar(
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
          scrolledUnderElevation: 0,
          actions: [
            BlocBuilder<KhatmaCubit, KhatmaState>(
              builder: (context, state) {
                if (state is KhatmaLoaded && state.khatmas.length == 1) {
                  final khatma = state.khatmas.first;
                  return IconButton(
                    tooltip: 'تعديل وقت التنبيه',
                    icon: const Icon(FontAwesomeIcons.clock, color: Color(0xFFD0A871)),
                    onPressed: () {
                      if (khatma.notificationType == 'prayer') {
                        _showPrayerOffsetsDialog(context, context.read<KhatmaCubit>(), khatma);
                      } else {
                        _showTimePickerDialog(context, context.read<KhatmaCubit>(), khatma.dailyTime, khatma.id);
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),'''

content = re.sub(r'        appBar: AppBar\([\s\S]*?scrolledUnderElevation: 0,\s*\),', app_bar, content)

with open('lib/features/wird/ui/wird_dashboard_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
