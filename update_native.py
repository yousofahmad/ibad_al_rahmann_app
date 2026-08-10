# -*- coding: utf-8 -*-
import re

# 1. MainApplication.kt
main_app = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\MainApplication.kt'
with open(main_app, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the receiver registration block
start = content.find('// Register Screen Unlock Receiver dynamically')
if start != -1:
    end = content.find('} catch (e: Exception) {', start)
    end = content.find('}', end + 1) + 1
    content = content[:start] + content[end:]
    # Remove whitespace
    content = re.sub(r'\n\s*\n', '\n\n', content)
    with open(main_app, 'w', encoding='utf-8') as f:
        f.write(content)

# 2. MainActivity.kt
main_act = r'd:\flutter\ibad_al_rahmann\android\app\src\main\kotlin\app\ibad_al_rahmann\MainActivity.kt'
with open(main_act, 'r', encoding='utf-8') as f:
    act_content = f.read()

if 'app.ibad_al_rahmann/background' not in act_content:
    channel_code = '''        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.ibad_al_rahmann/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenUnlockService" -> {
                    try {
                        val serviceIntent = Intent(this, ScreenUnlockForegroundService::class.java)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopScreenUnlockService" -> {
                    try {
                        val serviceIntent = Intent(this, ScreenUnlockForegroundService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
'''
    insert_pos = act_content.find('MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.ibad_al_rahmann/native_prayer")')
    if insert_pos != -1:
        act_content = act_content[:insert_pos] + channel_code + "\n" + act_content[insert_pos:]
        with open(main_act, 'w', encoding='utf-8') as f:
            f.write(act_content)

# 3. AndroidManifest.xml
manifest_path = r'd:\flutter\ibad_al_rahmann\android\app\src\main\AndroidManifest.xml'
with open(manifest_path, 'r', encoding='utf-8') as f:
    manifest = f.read()

if 'ScreenUnlockForegroundService' not in manifest:
    service_decl = '''
        <service
            android:name=".ScreenUnlockForegroundService"
            android:enabled="true"
            android:exported="false"
            android:foregroundServiceType="specialUse" />
'''
    # insert before </application>
    app_end = manifest.find('</application>')
    manifest = manifest[:app_end] + service_decl + manifest[app_end:]
    with open(manifest_path, 'w', encoding='utf-8') as f:
        f.write(manifest)

print("Updated MainApplication, MainActivity, and AndroidManifest")