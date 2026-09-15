$outfile = "D:\flutter\ibad_al_rahmann\prompt_result.md"
"#" + " 1. Git Status & Diff" | Out-File -FilePath $outfile -Encoding utf8
git status | Out-File -FilePath $outfile -Encoding utf8 -Append
git diff --stat origin/main | Out-File -FilePath $outfile -Encoding utf8 -Append

"`n#" + " 2. lib/features/wird/ui/khatma_details_screen.dart" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "lib/features/wird/ui/khatma_details_screen.dart") {
    Get-Content -Path "lib/features/wird/ui/khatma_details_screen.dart" -Encoding UTF8 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. lib/features/wird/ui/khatma_details_view.dart (Lines 950-1050)" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "lib/features/wird/ui/khatma_details_view.dart") {
    Get-Content -Path "lib/features/wird/ui/khatma_details_view.dart" -Encoding UTF8 | Select-Object -Skip 949 -First 101 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. lib/services/notification_service.dart" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "lib/services/notification_service.dart") {
    Get-Content -Path "lib/services/notification_service.dart" -Encoding UTF8 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt") {
    Get-Content -Path "android/app/src/main/kotlin/app/ibad_al_rahmann/AlarmReceiver.kt" -Encoding UTF8 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. android/app/src/main/kotlin/app/ibad_al_rahmann/KhatmaHelper.kt" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "android/app/src/main/kotlin/app/ibad_al_rahmann/KhatmaHelper.kt") {
    Get-Content -Path "android/app/src/main/kotlin/app/ibad_al_rahmann/KhatmaHelper.kt" -Encoding UTF8 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt (Lines 200-300)" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt") {
    Get-Content -Path "android/app/src/main/kotlin/app/ibad_al_rahmann/NativeAzkarScheduler.kt" -Encoding UTF8 | Select-Object -Skip 199 -First 101 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 2. android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt" | Out-File -FilePath $outfile -Encoding utf8 -Append
if (Test-Path "android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt") {
    Get-Content -Path "android/app/src/main/kotlin/app/ibad_al_rahmann/BackgroundMethodChannelPlugin.kt" -Encoding UTF8 | Out-File -FilePath $outfile -Encoding utf8 -Append
}

"`n#" + " 3. Untracked files" | Out-File -FilePath $outfile -Encoding utf8 -Append
git ls-files --others --exclude-standard | Out-File -FilePath $outfile -Encoding utf8 -Append

