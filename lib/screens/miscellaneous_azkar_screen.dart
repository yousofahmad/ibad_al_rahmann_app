import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import '../data/azkar_data.dart'; // تأكد إن المسار ده صح عندك

class AzkarVariousScreen extends StatefulWidget {
  const AzkarVariousScreen({super.key});

  @override
  State<AzkarVariousScreen> createState() => _AzkarVariousScreenState();
}

class _AzkarVariousScreenState extends State<AzkarVariousScreen> {
  List<AzkarItem>? _selectedAzkar;
  String? _selectedTitle;

  @override
  Widget build(BuildContext context) {
    // تعريف الألوان حسب الوضع
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // الألوان الديناميكية
    final cardColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(
            0xFFF3E5AB,
          ).withValues(alpha: 0.9); // بيج في الفاتح، غامق في الليلي
    const cardBorderColor = Color(0xFFD0A871);
    final titleColor = isDark
        ? Colors.white
        : const Color(0xFF5D4037); // بني في الفاتح، أبيض في الليلي

    // خلفية الأذكار التفصيلية
    final detailCardColor = isDark
        ? const Color(0xFF2C2C2C).withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);
    final detailTextColor = isDark ? Colors.white : Colors.black;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          // ==========================================
          // الهيدر الموحد (تدريج ذهبي + حواف دائرية)
          // ==========================================
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF2D69D),
                  Color(0xFFD0A871),
                  Color(0xFFB88A4A),
                ],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Color(0xFF3E2723),
            ), // لون بني غامق
            onPressed: () {
              if (_selectedAzkar != null) {
                setState(() {
                  _selectedAzkar = null;
                  _selectedTitle = null;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _selectedTitle ?? 'أذكار متنوعة',
            style: const TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Color(0xFF3E2723), // لون بني غامق
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              // الصورة اللي أنت اخترتها
              image: AssetImage(
                'assets/images/cecddf5ed195d31a4c6f1b44a9cfed3f.jpg',
              ),
              fit: BoxFit.cover,
            ),
          ),
          // طبقة تعتيم فوق الصورة عشان الكلام يبان (أغمق في الليلي)
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark
                      ? Colors.black.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.3),
                  isDark
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 20,
                ),
                child: _selectedAzkar != null
                    ? _buildAzkarList(
                        detailCardColor,
                        cardBorderColor,
                        detailTextColor,
                      )
                    : _buildButtonsList(cardColor, titleColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonsList(Color btnColor, Color txtColor) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _customAzkarButton(
          'دعاء للمهندس أحمد',
          engineerDua,
          btnColor,
          txtColor,
        ),
        _customAzkarButton('أذكار النوم', sleepAzkar, btnColor, txtColor),
        _customAzkarButton('أذكار الاستيقاظ', wakeUpAzkar, btnColor, txtColor),
        _customAzkarButton('أذكار الأذان', adhanAzkar, btnColor, txtColor),
      ],
    );
  }

  Widget _customAzkarButton(
    String title,
    List<AzkarItem> data,
    Color bgColor,
    Color txtColor,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedAzkar = data;
          _selectedTitle = title;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor, // اللون المتغير حسب الوضع
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFD0A871).withValues(alpha: 0.5),
            width: 1,
          ), // إطار خفيف
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: txtColor, // اللون المتغير
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAzkarList(Color cardColor, Color borderColor, Color textColor) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _selectedAzkar!.length,
      padding: const EdgeInsets.only(top: 10),
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _selectedAzkar![index].arabicText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppConsts.amiri,
              // استخدمت خط أميري للقراءة المريحة
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.8,
              color: textColor,
            ),
          ),
        );
      },
    );
  }
}
