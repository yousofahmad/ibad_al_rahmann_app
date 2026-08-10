import re
content = open(r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart', 'r', encoding='utf-8').read()

dropdown = '''
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "قناة تشغيل الأذان الأساسية",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "اختر القناة التي سيعمل عليها الأذان لتجنب تداخله مع وضع الصامت.",
                    style: TextStyle(
                      fontFamily: AppConsts.cairo,
                      fontSize: 12.sp,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    value: _audioStream,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'alarm', child: Text("قناة المنبه (الافتراضي)", style: TextStyle(fontFamily: AppConsts.cairo))),
                      DropdownMenuItem(value: 'media', child: Text("قناة الوسائط (الميديا)", style: TextStyle(fontFamily: AppConsts.cairo))),
                      DropdownMenuItem(value: 'ringtone', child: Text("قناة الرنين / الإشعارات", style: TextStyle(fontFamily: AppConsts.cairo))),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _audioStream = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('audio_stream_channel', val);
                      }
                    },
                  ),
                ],
              ),
            ),
'''

if 'قناة تشغيل الأذان' not in content:
    idx = content.find('Icon(Icons.volume_up, color: const Color(0xFFD0A871), size: 20.sp),\n                  ],\n                ),\n              ),')
    if idx != -1:
        end_idx = idx + len('Icon(Icons.volume_up, color: const Color(0xFFD0A871), size: 20.sp),\n                  ],\n                ),\n              ),')
        new_content = content[:end_idx] + dropdown + content[end_idx:]
        open(r'd:\flutter\ibad_al_rahmann\lib\screens\settings_screen.dart', 'w', encoding='utf-8').write(new_content)
        print('Injected successfully')
    else:
        print('Target not found')
else:
    print('Already injected')
