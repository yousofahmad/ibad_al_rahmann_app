const fs = require('fs');

let out = fs.readFileSync('prompt_result.md', 'utf8');

const files = [
  'lib/features/wird/ui/khatma_details_screen.dart',
  'lib/features/wird/ui/khatma_details_view.dart',
  'lib/services/notification_service.dart',
  'android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt',
  'android/app/src/main/kotlin/app/ibad_al_rahmann/KhatmaHelper.kt',
  'android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt',
  'android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt'
];

for (const file of files) {
  if (fs.existsSync(file)) {
    out += '\n#### ' + file + '\n';
    out += '`\n';
    
    let content = fs.readFileSync(file, 'utf8');
    let lines = content.split('\n');
    
    if (file.includes('khatma_details_view.dart')) {
      if (lines.length >= 950) {
        let end = Math.min(1050, lines.length);
        out += lines.slice(949, end).join('\n') + '\n';
      } else {
        out += '// File has less than 950 lines.\n';
      }
    } else if (file.includes('NativeAzkarScheduler.kt')) {
      if (lines.length >= 200) {
        let end = Math.min(300, lines.length);
        out += lines.slice(199, end).join('\n') + '\n';
      } else {
        out += '// File has less than 200 lines.\n';
      }
    } else if (file.includes('notification_service.dart')) {
      // Just extract scheduleAll and _scheduleKhatmaNotifications
      let match1 = content.match(/static Future<void> scheduleAll.*?\n  }/s);
      if (match1) out += match1[0] + '\n\n';
      
      let match2 = content.match(/static Future<void> _scheduleKhatmaNotifications.*?\n  }/s);
      if (match2) out += match2[0] + '\n\n';
    } else {
      out += content + '\n';
    }
    
    out += '`\n';
  } else {
    out += '\n#### ' + file + ' (Not Found)\n';
  }
}

out += '\n### 3. New Files Locally (Not in Repo)\n';
out += '`\n.ai_plans/\nlib/screens/hijri_confirmation_screen.dart\nlib/services/hijri_source_service.dart\n`\n';

fs.writeFileSync('prompt_result.md', out);
