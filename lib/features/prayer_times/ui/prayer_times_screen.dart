import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/alert_helper.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/widgets_ext.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/di.dart';
import '../logic/prayer_times_cubit/prayer_times_cubit.dart';
import 'widgets/permission_panel_widget.dart';
import 'widgets/prayer_times_screen_body_builder.dart';

// enum PrayerTimes { fajr, shrouk, duhur, asr, maghrib, isha }

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  bool hasPermission = false;
  bool serviceEnabled = true;
  bool permissionPermanentlyDenied = false;

  Future<void> _refreshStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    // final status = await Permission.location.status;
    setState(() {
      serviceEnabled = enabled;
      // hasPermission = status.isGranted;
      // permissionPermanentlyDenied = status.isPermanentlyDenied;
    });
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          AlertHelper.showWarningAlert(
            context,
            message: 'تم رفض صلاحية الموقع. لن تعمل مواعيد الصلاة تلقائيًا.',
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        AlertHelper.showWarningAlert(
          context,
          message: 'الرجاء تفعيل صلاحية الموقع من الإعدادات.',
        );
      }
      permissionPermanentlyDenied = true;
    }
    setState(() {
      hasPermission = true;
    });
    // final result = await Permission.location.request();
    // await _refreshStatus();
    // if (result.isGranted) {
    //   AlertHelper.showSuccessAlert(context, message: 'تم منح صلاحية الموقع.');
    // } else if (result.isPermanentlyDenied) {
    //   AlertHelper.showWarningAlert(
    //     context,
    //     message: 'الرجاء تفعيل صلاحية الموقع من الإعدادات.',
    //   );
    // } else {
    //   AlertHelper.showWarningAlert(
    //     context,
    //     message: 'تم رفض صلاحية الموقع. لن تعمل مواعيد الصلاة تلقائيًا.',
    //   );
    // }
  }

  Future<void> _openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened) return;
    await _refreshStatus();
  }

  Future<void> _openAppSettings() async {
    final opened = await openAppSettings();
    if (!opened) return;
    await _refreshStatus();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Builder(
        builder: (context) {
          if (!serviceEnabled) {
            return PermissionPanel(
              icon: Icons.location_disabled,
              title: 'خدمة الموقع متوقفة',
              message:
                  'فعّل خدمة الموقع من شريط الإشعارات أو الإعدادات لتحديد اتجاه القبلة.',
              primaryLabel: 'فتح إعدادات الموقع',
              onPrimaryPressed: _openLocationSettings,
              secondaryLabel: 'تحديث الحالة',
              onSecondaryPressed: _refreshStatus,
            );
          }

          if (!hasPermission && permissionPermanentlyDenied) {
            return PermissionPanel(
              icon: Icons.lock,
              title: 'الصلاحية مرفوضة دائمًا',
              message:
                  'لا يمكن عرض مواعيد الصلاة بدون صلاحية الموقع. افتح الإعدادات ومنح الإذن.',
              primaryLabel: 'فتح إعدادات التطبيق',
              onPrimaryPressed: _openAppSettings,
              secondaryLabel: 'تحديث الحالة',
              onSecondaryPressed: _refreshStatus,
            );
          }

          if (!hasPermission) {
            return PermissionPanel(
              icon: Icons.location_on,
              title: 'مطلوب صلاحية الموقع',
              message:
                  'نستخدم موقعك لجلب مواعيد الصلاة لمنطقتك. الرجاء منح الإذن للمتابعة.',
              primaryLabel: 'منح الإذن',
              onPrimaryPressed: _requestPermission,
              secondaryLabel: 'تحديث الحالة',
              onSecondaryPressed: _refreshStatus,
            );
          }

          return BlocProvider(
              create: (_) => PrayerTimesCubit(getIt()),
              child: const PrayerTimesScreenBodyBuilder(),
            );
        },
      ).withSafeArea(),
    );
  }
}


