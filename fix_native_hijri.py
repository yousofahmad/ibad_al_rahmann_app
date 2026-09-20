import re

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/NativePrayerManager.kt', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = '''
        var manualOffset = parseOffset("flutter.hijri_offset_manual")
        val storedMonth = parseOffset("flutter.hijri_offset_month")
        val localDelta = parseOffset("flutter.hijri_local_delta")
        val generalOffset = parseOffset("flutter.hijri_offset")
        
        // --- NEW LOGIC FOR PHASE 9.4 ---
        // HijriSourceService saves local_hijri_offset via CacheHelper (which prefixes it with flutter.)
        // It also has manual_day_adjustment (from Phase 1d if implemented)
        val sourceOffset = parseOffset("flutter.local_hijri_offset")
        val manualDayAdjustment = parseOffset("flutter.manual_day_adjustment")
'''
content = content.replace('''
        var manualOffset = parseOffset("flutter.hijri_offset_manual")
        val storedMonth = parseOffset("flutter.hijri_offset_month")
        val localDelta = parseOffset("flutter.hijri_local_delta")
        val generalOffset = parseOffset("flutter.hijri_offset")'''.strip('\n'), replacement.strip('\n'))

total_offset_replacement = '''
        val totalOffset = if (prefs.contains("flutter.local_hijri_offset")) {
            sourceOffset + manualDayAdjustment
        } else if (prefs.contains("flutter.hijri_offset_manual") || prefs.contains("flutter.hijri_local_delta")) {
            manualOffset + localDelta + parseOffset("flutter.global_hijri_offset")
        } else {
            generalOffset
        }
'''
content = content.replace('''
        val totalOffset = if (prefs.contains("flutter.hijri_offset_manual") || prefs.contains("flutter.hijri_local_delta")) {
            manualOffset + localDelta + parseOffset("flutter.global_hijri_offset")
        } else {
            generalOffset
        }'''.strip('\n'), total_offset_replacement.strip('\n'))

with open('android/app/src/main/kotlin/app/ibad_al_rahmann/NativePrayerManager.kt', 'w', encoding='utf-8') as f:
    f.write(content)
