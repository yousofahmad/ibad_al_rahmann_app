# -*- coding: utf-8 -*-
import re

path = r'd:\flutter\ibad_al_rahmann\lib\screens\home_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

if "import 'package:permission_handler/permission_handler.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:permission_handler/permission_handler.dart';")

old_code = '''      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        NotificationService.checkAndRequestBatteryPermission(context);
      }'''

new_code = '''      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        // Request essential permissions on startup
        try {
          await Permission.notification.request();
          if (await Permission.scheduleExactAlarm.isDenied) {
            await Permission.scheduleExactAlarm.request();
          }
        } catch (e) {
          debugPrint("Failed to request permissions: ");
        }
        if (mounted) {
          NotificationService.checkAndRequestBatteryPermission(context);
        }
      }'''

content = content.replace(old_code, new_code)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated home_screen.dart successfully")