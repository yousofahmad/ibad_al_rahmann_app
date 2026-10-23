import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/screens/fasting_days_screen.dart';
import 'package:ibad_al_rahmann/screens/fasting_tracker_screen.dart';
import 'package:ibad_al_rahmann/features/wird/ui/wird_dashboard_screen.dart';
import 'package:ibad_al_rahmann/screens/accountability_screen.dart';
import 'package:ibad_al_rahmann/features/share_cards/ui/share_cards_screen.dart';
import 'package:ibad_al_rahmann/screens/time_for_allah_screen.dart';
import 'package:ibad_al_rahmann/screens/occasions_screen.dart';
import 'package:ibad_al_rahmann/screens/hisn_muslim_screen.dart';
import 'package:ibad_al_rahmann/screens/nawawi_screen.dart';
import 'package:ibad_al_rahmann/screens/tasbeeh_screen.dart';
import 'package:ibad_al_rahmann/screens/muslim_azkar_screen.dart';
import 'package:ibad_al_rahmann/features/quran_reciters/ui/quran_readers_screen.dart';
import 'package:ibad_al_rahmann/screens/settings_screen.dart';
import 'package:ibad_al_rahmann/screens/stats_screen.dart';
import 'package:ibad_al_rahmann/screens/prayer_taqwim_screen.dart';
import 'package:ibad_al_rahmann/features/wird/ui/khatm_quran_duaa_screen.dart';
import 'package:ibad_al_rahmann/features/quran/ui/quran_screen.dart';
import 'package:ibad_al_rahmann/screens/prayer_focus_screen.dart';
import 'package:ibad_al_rahmann/screens/alarms_screen.dart';
import 'package:ibad_al_rahmann/screens/prayer_alarms_screen.dart';
import 'package:ibad_al_rahmann/screens/ramadan_screen.dart';
import 'package:ibad_al_rahmann/screens/qada_list_screen.dart';
import 'package:ibad_al_rahmann/screens/ruqyah_screen.dart';
import 'package:ibad_al_rahmann/screens/hijri_confirmation_screen.dart';
import 'package:ibad_al_rahmann/features/qadaa/ui/qadaa_screen.dart';
import 'package:ibad_al_rahmann/features/locations/ui/locations_list_screen.dart';
import 'package:ibad_al_rahmann/features/qiblah/qiblah_screen.dart';

class AppFeaturesGuideScreen extends StatefulWidget {
  const AppFeaturesGuideScreen({super.key});

  @override
  State<AppFeaturesGuideScreen> createState() => _AppFeaturesGuideScreenState();
}

class _AppFeaturesGuideScreenState extends State<AppFeaturesGuideScreen> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color goldColor = Color(0xFFD0A871);

  final List<String> _categories = [
    'الكل',
    'الصلوات والأذان',
    'المصحف والتفاسير',
    'الورد والختمات',
    'الأذكار وحصن المسلم',
    'حاسب نفسك',
    'الصيام والسنن',
    'التخصيص والمزامنة',
    'القبلة والموقع',
    'رمضان والعيد',
    'القضاء والفقه',
    'الرقية الشرعية',
    'التنبيهات',
    'التقويم الهجري',
    'المدن والمواقع',
  ];

  late final List<_FeatureItem> _features = [
    // 1. الصلوات والأذان
    _FeatureItem(
      category: 'الصلوات والأذان',
      title: 'نافذة "صلاتي" الذكية للتنبيه بالصلوات',
      badge: 'متاحة',
      badgeColor: const Color(0xFFE65100),
      icon: Icons.alarm_on_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'نافذة منبثقة تفاعلية تظهر فوق التطبيقات وشاشة القفل فور دخول وقت الصلاة، تتيح لك تسجيل أداء الصلاة بضغطة واحدة (في وقتها أو بعد وقتها)، أو تأجيل التنبيه، مع حساب نقاط الصلاة والإنجاز تلقائياً في الخلفية.',
      locationPath:
          'الشاشة الرئيسية > بطاقة صلاتي / الإعدادات > إعدادات الأذان والتنبيهات',
      actionTitle: 'فتح شاشة صلاتي',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PrayerFocusScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الصلوات والأذان',
      title: 'إحصائيات الصلوات والستريك الشهري',
      badge: 'متابعة',
      badgeColor: const Color(0xFFD32F2F),
      icon: Icons.insights_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'رسوم بيانية توضح معدل التزامك بالصلوات، وسلاسل الالتزام المتواصلة (Streak) التراكمية عبر الشهور، وتحليل الصلاة الأكثر تأخيراً مع تقويم شهري تفاعلي.',
      locationPath: 'الشاشة الرئيسية > صلاتي > أيقونة الإحصائيات (أعلى اليسار)',
      actionTitle: 'عرض إحصائيات صلاتي',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const StatsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الصلوات والأذان',
      title: 'تقويم ومواقيت الصلوات والثلث الأخير',
      badge: 'مواقيت',
      badgeColor: const Color(0xFF1976D2),
      icon: Icons.calendar_month_rounded,
      iconColor: const Color(0xFF0288D1),
      description:
          'استعراض مواقيت الأذان والصلوات لكل يوم مع أوقات الشروق والضحى، وحساب ثلث الليل الأول ومنتصف الليل وثلث الليل الأخير لقيام الليل، وتصدير بطاقات التقويم كصور ومشاركتها.',
      locationPath: 'الشاشة الرئيسية > الضغط على بطاقة مواقيت الصلاة',
      actionTitle: 'فتح تقويم الصلاة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PrayerTaqwimScreen()),
      ),
    ),

    // 2. المصحف والتفاسير
    _FeatureItem(
      category: 'المصحف والتفاسير',
      title:
          'المكتبة الصوتية الشاملة (41 قارئاً) وتشغيل الصوت وتظليل الكلمات والآيات',
      badge: 'صوتيات',
      badgeColor: const Color(0xFF2E7D32),
      icon: Icons.audiotrack_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'مشغل قرآني متطور يضم أكثر من 40 قارئاً من كبار قراء العالم الإسلامي بمختلف الروايات، مع تشغيل الصوت وتظليل الكلمات والآيات المتزامن بالمللي ثانية، وسرعات استماع متعددة، والتحميل الكامل للاستماع بدون إنترنت.',
      locationPath:
          'المصحف الشريف > الضغط على أي آية > مشغل الصوت / أو من شاشة القراء',
      actionTitle: 'فتح مكتبة القراء',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QuranReadersScreen()),
      ),
    ),
    _FeatureItem(
      category: 'المصحف والتفاسير',
      title: 'تفاسير القرآن المعتمدة أوفلاين (ابن كثير والطبري)',
      badge: 'موسوعة علمية ',
      badgeColor: const Color(0xFF5C6BC0),
      icon: Icons.auto_stories_rounded,
      iconColor: const Color(0xFF3F51B5),
      description:
          'إمكانية تنزيل وقراءة التفاسير المتاحة داخل المصحف بدون اتصال بالإنترنت، مع التبديل الفوري بين كتب التفسير بنقرة واحدة على أي آية.',
      locationPath: 'المصحف الشريف > الضغط على الآية > التفسير والمعاني',
      actionTitle: 'فتح المصحف والتفاسير',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QuranScreen()),
      ),
    ),
    _FeatureItem(
      category: 'المصحف والتفاسير',
      title: 'التبديل بين الوضع المكبر والمصغر وعلامات الأحزاب',
      badge: 'راحة القراءة ',
      badgeColor: const Color(0xFF00838F),
      icon: Icons.zoom_in_rounded,
      iconColor: const Color(0xFF00ACC1),
      description:
          'اضغط ضغطاً مزدوجاً (Double Tap) داخل صفحة المصحف للتبديل الفوري بين وضع التكبير للقراءة المريحة والوضع القياسي، مع إظهار علامات الحزب (بداية، نصف، ثلاثة أرباع) بدقة متناهية.',
      locationPath: 'المصحف الشريف > النقر المزدوج على أي صفحة',
      actionTitle: 'فتح المصحف الشريف',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QuranScreen()),
      ),
    ),

    // 3. الورد والختمات
    _FeatureItem(
      category: 'الورد والختمات',
      title: 'نظام الختمات والورد القرآني اليومي',
      badge: 'ختم القرآن ',
      badgeColor: const Color(0xFFD0A871),
      icon: Icons.menu_book_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'إنشاء ختمات متعددة (ختمة شهرية، تدبر، سنوية) مع تحديد وتيرة الورد، وحفظ تقدم الصفحات تلقائياً، وإمكانية تدوين الملاحظات والفوائد على الآيات، ومشاركة إنجاز الورد كصورة أو نص، ودعاء ختم القرآن.',
      locationPath:
          'الشاشة الرئيسية > قسم القرآن والورد / أو المزيد > الورد القرآني',
      actionTitle: 'فتح شاشة الختمات',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const WirdDashboardScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الورد والختمات',
      title: 'قارئ الورد بصفحات المصحف الأصيلة (15 سطراً)',
      badge: 'جديد ',
      badgeColor: const Color(0xFF00897B),
      icon: Icons.chrome_reader_mode_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'قارئ مخصص للورد القرآني يعرض صفحات المصحف الشريف بكامل بهائها (15 سطراً) بنظام الـ Fullscreen مع شريط علوي وسفلي ذكي يختفي أثناء القراءة لتجربة خاشعة وغامرة.',
      locationPath: 'الورد القرآني > الضغط على الختمة > قراءة الورد',
      actionTitle: 'عرض الختمات النشطة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const WirdDashboardScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الورد والختمات',
      title: 'دعاء ختم القرآن المأثور وبطاقات المشاركة',
      badge: 'مأثور وموثوق ',
      badgeColor: const Color(0xFFD0A871),
      icon: Icons.auto_stories_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'دعاء ختم القرآن الكريم المأثور والمستحب من كتاب الأذكار للإمام النووي، مع إمكانية تكبير وتصغير الخط، ومشاركة النص كاملاً، أو تصدير الدعاء كبطاقة إسلامية فاخرة بثيمات متعددة جاهزة للمشاركة وحفظها في المعرض.',
      locationPath: 'الورد القرآني > دعاء ختم القرآن',
      actionTitle: 'فتح دعاء ختم القرآن',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const KhatmQuranDuaaScreen()),
      ),
    ),

    // 4. الأذكار وحصن المسلم
    _FeatureItem(
      category: 'الأذكار وحصن المسلم',
      title: 'أذكار الصباح والمساء والستريك التلقائي',
      badge: 'حصن يومي ',
      badgeColor: const Color(0xFFF57F17),
      icon: Icons.wb_sunny_rounded,
      iconColor: const Color(0xFFF57F17),
      description:
          'أذكار الصباح والمساء وأذكار النوم والاستيقاظ وأذكار بعد الصلاة مع عدادات تفاعلية، واحتساب الستريك اليومي تلقائياً بمجرد إنجاز 50% من العدادات، واستعراض إحصائيات تكرار كل ذكر عبر التاريخ.',
      locationPath: 'الشاشة الرئيسية > بطاقات الأذكار / قسم الأذكار',
      actionTitle: 'فتح الأذكار',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const MuslimAzkarScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الأذكار وحصن المسلم',
      title: 'حصن المسلم الشامل مع البحث الفوري',
      badge: 'أدعية وأذكار ',
      badgeColor: const Color(0xFF43A047),
      icon: Icons.shield_rounded,
      iconColor: const Color(0xFF43A047),
      description:
          'موسوعة أدعية حصن المسلم مقسمة حسب الأبواب والمناسبات، مع بحث في عناوين ونصوص الأدعية، وإمكانية تفضيل الأدعية ومشاركتها كبطاقات.',
      locationPath: 'الشاشة الرئيسية > بطاقة حصن المسلم',
      actionTitle: 'فتح حصن المسلم',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const HisnMuslimScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الأذكار وحصن المسلم',
      title: 'الأربعون النووية مع الشرح والفوائد',
      badge: 'سنة نبوية ',
      badgeColor: const Color(0xFF6D4C41),
      icon: Icons.library_books_rounded,
      iconColor: const Color(0xFF8D6E63),
      description:
          'الأحاديث الأربعون النووية كاملة مع شروح ميسرة لكل حديث، ومحرك بحث ذكي، مع تمييز وتظليل كلمات البحث المطابقة وتكبير حجم الخط المريح.',
      locationPath: 'الشاشة الرئيسية > بطاقة الأربعون النووية',
      actionTitle: 'فتح الأربعون النووية',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const NawawiScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الأذكار وحصن المسلم',
      title: 'المسبحة الإلكترونية التفاعلية',
      badge: 'تسبيح وذكر ',
      badgeColor: const Color(0xFF00897B),
      icon: Icons.fingerprint_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'مسبحة إلكترونية بأصوات واهتزازات لمسية قابلة للتخصيص، مع إمكانية إضافة أذكار مخصصة وتحديد أهداف يومية، ومتابعة إجمالي التسبيحات عبر الزمن.',
      locationPath: 'الشاشة الرئيسية > بطاقة المسبحة',
      actionTitle: 'فتح المسبحة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const TasbeehScreen()),
      ),
    ),

    // 5. حاسب نفسك
    _FeatureItem(
      category: 'حاسب نفسك',
      title: 'حاسب نفسك والمزامنة التلقائية مع صلاتي',
      badge: 'مراقبة الذات ',
      badgeColor: const Color(0xFFD0A871),
      icon: Icons.checklist_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'شاشة شاملة لمحاسبة النفس على الصلوات، والسنن الرواتب، والورد القرآني، والأذكار، والأعمال الصالحة. يتم تحديث بنود الصلاة والورد فيها تلقائياً فور تسجيلها من الإشعارات أو شاشة القفل دون الحاجة لفتحها، مع تصفير نظيف كل فجر.',
      locationPath: 'الشاشة الرئيسية > بطاقة حاسب نفسك',
      actionTitle: 'فتح حاسب نفسك',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AccountabilityScreen()),
      ),
    ),

    // 6. الصيام والسنن
    _FeatureItem(
      category: 'الصيام والسنن',
      title: 'أيام الصيام وبطاقات ستوري واتساب (9:16)',
      badge: 'متاحة',
      badgeColor: const Color(0xFFE65100),
      icon: Icons.stay_current_portrait_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'جدول شهري بأيام صيام التطوع (الاثنين والخميس، الأيام البيض، عاشوراء، عرفة، وغيرها) مع إمكانية تصدير بطاقات ستوري واتساب 9:16 بمقاس مناسب للمشاركة وبألوان داكنة وفاتحة فاخرة وإرفاق 29 نية مباركة لصيام التطوع.',
      locationPath: 'المزيد > أيام الصيام',
      actionTitle: 'فتح أيام الصيام',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const FastingDaysScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الصيام والسنن',
      title: 'سجل الصيام وقضاء الفوائت',
      badge: 'متابعة الصيام ',
      badgeColor: const Color(0xFF00897B),
      icon: Icons.event_available_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'سجل تقويمي تفاعلي لتسجيل الأيام التي صمتها من تطوع أو قضاء، مع حساب إجمالي الأيام المصومة وتتبع الأيام المتبقية عليك لقضائها.',
      locationPath: 'المزيد > سجل الصيام (أو من داخل أيام الصيام)',
      actionTitle: 'فتح سجل الصيام',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const FastingTrackerScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الصيام والسنن',
      title: 'المناسبات الإسلامية والتقويم الهجري',
      badge: 'أعياد ومناسبات ',
      badgeColor: const Color(0xFF5C6BC0),
      icon: Icons.celebration_rounded,
      iconColor: const Color(0xFF5C6BC0),
      description:
          'استعراض كافة المناسبات الإسلامية (رأس السنة الهجرية، المولد النبوي، الإسراء والمعراج، رمضان، الأعياد) مع العد التنازلي التفاعلي لأقرب مناسبة.',
      locationPath: 'المزيد > المناسبات',
      actionTitle: 'فتح المناسبات',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const OccasionsScreen()),
      ),
    ),

    // ميزات الصيام الموسمية والقضاء
    _FeatureItem(
      category: 'رمضان والعيد',
      title: 'لوحة رمضان وتنبيهات العيد',
      badge: 'رمضان والعيد',
      badgeColor: const Color(0xFF00897B),
      icon: Icons.nightlight_round,
      iconColor: const Color(0xFF00897B),
      description:
          'لوحة عملية لرمضان تعرض بطاقات الإفطار والسحور، وتتيح ضبط تنبيهات مرتبطة بهما، مع أدوات مخصصة لصلاة العيد وتذكيراتها.',
      locationPath: 'المزيد > رمضان',
      actionTitle: 'فتح لوحة رمضان',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const RamadanScreen()),
      ),
    ),
    _FeatureItem(
      category: 'القضاء والفقه',
      title: 'متابعة قضاء الصيام والصلوات',
      badge: 'قضاء',
      badgeColor: const Color(0xFF6D4C41),
      icon: Icons.assignment_turned_in_rounded,
      iconColor: const Color(0xFF6D4C41),
      description:
          'تسجيل ما عليك من قضاء الصيام والصلوات ومتابعة المتبقي، مع إعدادات الفقه المرتبطة بالحساب دون ادعاء إصدار فتوى.',
      locationPath: 'المزيد > القضاء',
      actionTitle: 'فتح متابعة القضاء',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QadaaScreen()),
      ),
    ),
    _FeatureItem(
      category: 'القضاء والفقه',
      title: 'سجل أيام قضاء الصيام',
      badge: 'سجل القضاء',
      badgeColor: const Color(0xFF00897B),
      icon: Icons.event_note_rounded,
      iconColor: const Color(0xFF00897B),
      description:
          'عرض سجل أيام القضاء المرتبطة ببطاقات رمضان وتحديثها من شاشة واحدة.',
      locationPath: 'رمضان > أيام القضاء',
      actionTitle: 'فتح سجل القضاء',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QadaListScreen()),
      ),
    ),
    _FeatureItem(
      category: 'الرقية الشرعية',
      title: 'الرقية الشرعية من النصوص المضمنة',
      badge: 'رقية',
      badgeColor: const Color(0xFF2E7D32),
      icon: Icons.menu_book_rounded,
      iconColor: const Color(0xFF2E7D32),
      description:
          'قراءة نصوص الرقية الشرعية المضمنة في التطبيق ونسخ النص عند الحاجة، دون نسب فوائد علاجية أو وعود طبية.',
      locationPath: 'المزيد > الرقية الشرعية',
      actionTitle: 'فتح الرقية الشرعية',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const RuqyahScreen()),
      ),
    ),
    // تنبيهات الصلاة والتقويم والمواقع
    _FeatureItem(
      category: 'التنبيهات',
      title: 'تخصيص تنبيهات الأذان والصلاة',
      badge: 'تنبيهات الصلاة',
      badgeColor: const Color(0xFFE65100),
      icon: Icons.notifications_active_rounded,
      iconColor: const Color(0xFFE65100),
      description:
          'تشغيل أو إيقاف تنبيهات الصلوات وتخصيص مدة الصمت وخيارات الأذان لكل صلاة من إعدادات التنبيهات.',
      locationPath: 'الإعدادات > تنبيهات الصلاة',
      actionTitle: 'فتح تنبيهات الصلاة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const PrayerAlarmsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'التقويم الهجري',
      title: 'التاريخ الهجري المصري ومراجعة المصدر',
      badge: 'مصدر رسمي',
      badgeColor: const Color(0xFFC2185B),
      icon: Icons.fact_check_rounded,
      iconColor: const Color(0xFFC2185B),
      description:
          'مراجعة التاريخ الهجري المصري وتأكيده عند اختلاف المصادر، مع مزامنة البيانات من المصادر الرسمية المتاحة في التطبيق.',
      locationPath: 'الإعدادات > النظام الهجري المعتمد',
      actionTitle: 'مراجعة التاريخ الهجري',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const HijriConfirmationScreen()),
      ),
    ),
    _FeatureItem(
      category: 'المدن والمواقع',
      title: 'إدارة مدن متعددة لمواقيت الصلاة',
      badge: 'مواقع متعددة',
      badgeColor: const Color(0xFF1976D2),
      icon: Icons.location_city_rounded,
      iconColor: const Color(0xFF1976D2),
      description:
          'إضافة أكثر من مدينة وحفظ إعدادات كل مدينة وطريقة الحساب والفروق الزمنية لاستخدام مواقيت مناسبة لكل موقع.',
      locationPath: 'الإعدادات > المدن والمواقع',
      actionTitle: 'إدارة المدن والمواقع',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const LocationsListScreen()),
      ),
    ),

    // 7. القبلة والموقع
    _FeatureItem(
      category: 'القبلة والموقع',
      title: 'بوصلة القبلة',
      badge: 'اتجاه القبلة',
      badgeColor: const Color(0xFF1976D2),
      icon: Icons.explore_rounded,
      iconColor: const Color(0xFF1976D2),
      description:
          'تحديد اتجاه القبلة باستخدام بوصلة الجهاز مع إرشادات لتحسين دقة القراءة عند الحاجة إلى معايرة الجهاز.',
      locationPath: 'الشاشة الرئيسية > أداة القبلة',
      actionTitle: 'فتح بوصلة القبلة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const QiblahScreen()),
      ),
    ),

    // 8. التخصيص والمزامنة
    _FeatureItem(
      category: 'التخصيص والمزامنة',
      title: 'الصلاة على النبي ﷺ عند فتح قفل الشاشة',
      badge: 'بركة اليوم ',
      badgeColor: const Color(0xFF2E7D32),
      icon: Icons.screen_lock_portrait_rounded,
      iconColor: const Color(0xFF43A047),
      description:
          'تذكير صوتي بالصلاة على النبي ﷺ ينطلق تلقائياً بمجرد فتح قفل هاتفك، مع إمكانية تحديد أصوات متنوعة أو اختيار نغمة مخصصة من ملفات هاتفك والتحكم في مستوى الصوت ومعدل التكرار.',
      locationPath: 'المزيد > تنبيهات الصلاة على النبي',
      actionTitle: 'فتح تنبيهات الصلاة على النبي',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const AlarmsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'التخصيص والمزامنة',
      title: 'النسخ الاحتياطي والمزامنة السحابية مع Google Drive',
      badge: 'أمان بياناتك ',
      badgeColor: const Color(0xFF1976D2),
      icon: Icons.cloud_sync_rounded,
      iconColor: const Color(0xFF1976D2),
      description:
          'حفظ وأرشفة كافة إنجازاتك وختماتك وإحصائيات صلواتك وأذكارك محلياً أو سحابياً على حسابك في Google Drive، مع إمكانية استعادتها فوراً على أي هاتف آخر بنقرة واحدة.',
      locationPath: 'الإعدادات > النسخ الاحتياطي والمزامنة',
      actionTitle: 'فتح النسخ الاحتياطي',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'التخصيص والمزامنة',
      title: 'تثبيت ومزامنة التاريخ الهجري المصري وهيئة المساحة',
      badge: 'دقة شرعية',
      badgeColor: const Color(0xFFC2185B),
      icon: Icons.calendar_today_rounded,
      iconColor: const Color(0xFFE91E63),
      description:
          'نظام ذكي لمزامنة التاريخ الهجري الرسمي لجمهورية مصر العربية تلقائياً من دار الإفتاء وهيئة المساحة، مع قفل وتثبيت التاريخ طوال أيام الشهر حتى يوم 29 لضمان عدم حدوث أي قفزة أو خطأ.',
      locationPath: 'الإعدادات > النظام الهجري المعتمد > النظام المصري',
      actionTitle: 'فتح إعدادات التاريخ',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'التخصيص والمزامنة',
      title: 'بطاقات المشاركة الإسلامية الجاهزة',
      badge: 'نشر الخير ',
      badgeColor: const Color(0xFF7B1FA2),
      icon: Icons.grid_view_rounded,
      iconColor: const Color(0xFF9C27B0),
      description:
          'مجموعة فاخرة من البطاقات الدعوية الجاهزة (آيات، أحاديث، أدعية، أذكار) بتصاميم إسلامية عصرية مهيأة للمشاركة المباشرة كحالات واستوريات.',
      locationPath: 'المزيد > بطاقات المشاركة',
      actionTitle: 'فتح بطاقات المشاركة',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const ShareCardsScreen()),
      ),
    ),
    _FeatureItem(
      category: 'التخصيص والمزامنة',
      title: 'مبادرة "وقت لله"',
      badge: 'جلسة تدبر',
      badgeColor: const Color(0xFFD0A871),
      icon: Icons.hourglass_top_rounded,
      iconColor: const Color(0xFFD0A871),
      description:
          'تخصيص جلسة هادئة خالية من المشتتات لقضاء وقت خالص مع الله في الذكر أو التلاوة أو الدعاء، مع مؤقت هادئ وأجواء روحانية مريحة.',
      locationPath: 'المزيد > وقت لله',
      actionTitle: 'فتح وقت لله',
      onAction: (ctx) => Navigator.push(
        ctx,
        MaterialPageRoute(builder: (_) => const TimeForAllahScreen()),
      ),
    ),
  ];

  List<_FeatureItem> get _filteredFeatures {
    return _features.where((item) {
      final matchesCategory =
          _selectedCategory == 'الكل' || item.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return matchesCategory;
      final matchesSearch =
          item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.locationPath.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text(
          "دليل مميزات التطبيق",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: goldColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A2418), const Color(0xFF1E1E1E)]
                    : [const Color(0xFFFFF9EE), const Color(0xFFFCF5E5)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: goldColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: goldColor,
                    size: 26.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "مميزات عباد الرحمن",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: goldColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "استكشف كافة الإمكانيات المتاحة وطريقة الوصول إليها بسهولة وتعرّف على المميزات المتاحة وطريقة الوصول إليها.",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 11.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'ابحث عن أي ميزة أو شاشة...',
                hintStyle: TextStyle(
                  fontFamily: AppConsts.cairo,
                  fontSize: 12.sp,
                  color: Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: goldColor),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardBg,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 16.w,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: goldColor, width: 1.5),
                ),
              ),
            ),
          ),

          // Category Chips Horizontal List
          SizedBox(
            height: 42.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 11.sp,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.black
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: goldColor,
                  backgroundColor: cardBg,
                  side: BorderSide(
                    color: isSelected
                        ? goldColor
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),

          SizedBox(height: 8.h),

          // Features List
          Expanded(
            child: _filteredFeatures.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          "لم يتم العثور على ميزات مطابقة للبحث",
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            fontSize: 13.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _filteredFeatures.length,
                    separatorBuilder: (_, __) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final item = _filteredFeatures[index];
                      return _buildFeatureCard(item, isDark, cardBg, textColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    _FeatureItem item,
    bool isDark,
    Color cardBg,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: item.iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 24.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: AppConsts.expoArabic,
                                fontSize: 14.5.sp,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (item.badge != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: (item.badgeColor ?? goldColor)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                item.badge!,
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: item.badgeColor ?? goldColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          fontSize: 10.5.sp,
                          color: goldColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Description
            Text(
              item.description,
              style: TextStyle(
                fontFamily: AppConsts.cairo,
                fontSize: 12.sp,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
              ),
            ),

            SizedBox(height: 12.h),

            // Location Box: أين تجدها في التطبيق
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF262626)
                    : const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.near_me_rounded, size: 14.sp, color: goldColor),
                  SizedBox(width: 8.w),
                  Text(
                    "المكان: ",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: goldColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.locationPath,
                      style: TextStyle(
                        fontFamily: AppConsts.cairo,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button if available
            if (item.onAction != null && item.actionTitle != null) ...[
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                height: 38.h,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldColor.withValues(alpha: 0.15),
                    foregroundColor: goldColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      side: const BorderSide(color: goldColor, width: 1),
                    ),
                  ),
                  icon: Icon(Icons.open_in_new_rounded, size: 16.sp),
                  label: Text(
                    item.actionTitle!,
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => item.onAction!(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String category;
  final String title;
  final String description;
  final String locationPath;
  final IconData icon;
  final Color iconColor;
  final String? badge;
  final Color? badgeColor;
  final String? actionTitle;
  final void Function(BuildContext context)? onAction;

  _FeatureItem({
    required this.category,
    required this.title,
    required this.description,
    required this.locationPath,
    required this.icon,
    required this.iconColor,
    this.badge,
    this.badgeColor,
    this.actionTitle,
    this.onAction,
  });
}
