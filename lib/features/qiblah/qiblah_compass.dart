import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../../core/helpers/alert_helper.dart';
import '../../core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/core/theme/app_images.dart';
import 'custom_compass.dart';

class QiblahCompass extends StatefulWidget {
  const QiblahCompass({super.key});

  @override
  State<QiblahCompass> createState() => _QiblahCompassState();
}

Animation<double>? animation;
AnimationController? _animationController;
double begin = 0.0;

class _QiblahCompassState extends State<QiblahCompass>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool hasPermission = false;
  bool serviceEnabled = true;
  bool permissionPermanentlyDenied = false;
  bool _wasAligned = false;
  static const double _alignmentThreshold = 2.0;

  bool? _deviceSupport;

  Future<void> _refreshStatus() async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      if (!mounted) return;

      setState(() {
        serviceEnabled = service;
        hasPermission =
            permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
        permissionPermanentlyDenied =
            permission == LocationPermission.deniedForever;
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        serviceEnabled = false;
        hasPermission = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!mounted) return;

    // Check current permission status using Geolocator
    LocationPermission permission = await Geolocator.checkPermission();

    // If already granted, just refresh
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _refreshStatus();
      if (mounted) {
        AlertHelper.showSuccessAlert(context, message: 'تم منح صلاحية الموقع.');
      }
      return;
    }

    // If permanently denied, open settings
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        await _openAppSettings();
      }
      return;
    }

    // Request permission using Geolocator (more reliable)
    permission = await Geolocator.requestPermission();
    await _refreshStatus();

    if (!mounted) return;

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      AlertHelper.showSuccessAlert(context, message: 'تم منح صلاحية الموقع.');
    } else if (permission == LocationPermission.deniedForever) {
      setState(() {
        permissionPermanentlyDenied = true;
      });
      AlertHelper.showWarningAlert(
        context,
        message: 'الرجاء تفعيل صلاحية الموقع من الإعدادات.',
      );
    } else if (permission == LocationPermission.denied) {
      // Permission was denied but not permanently
      AlertHelper.showWarningAlert(
        context,
        message: 'تم رفض صلاحية الموقع. لن تعمل ميزة تحديد القبلة.',
      );
    }
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
    _initializePermissions();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    animation = Tween(begin: 0.0, end: 0.0).animate(_animationController!);
  }

  Future<void> _initializePermissions() async {
    final support = await FlutterQiblah.androidDeviceSensorSupport();
    if (mounted) setState(() => _deviceSupport = support);

    await _refreshStatus();
    // Auto-request permission if not granted and not permanently denied
    if (hasPermission == false &&
        permissionPermanentlyDenied == false &&
        serviceEnabled == true &&
        _deviceSupport == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await _requestPermission();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController?.dispose();
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
    return Builder(
      builder: (context) {
        if (_deviceSupport == false) {
          return _PermissionPanel(
            icon: Icons.dangerous,
            title: 'الجهاز غير مدعوم',
            message: 'هذا الجهاز لا يحتوي على مستشعرات البوصلة المطلوبة.',
            primaryLabel: 'حسناً',
            onPrimaryPressed: () {},
          );
        }

        if (!serviceEnabled) {
          return _PermissionPanel(
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
          return _PermissionPanel(
            icon: Icons.lock,
            title: 'الصلاحية مرفوضة دائمًا',
            message:
                'لا يمكن للتطبيق العمل دون صلاحية الموقع. افتح الإعدادات ومنح الإذن.',
            primaryLabel: 'فتح إعدادات التطبيق',
            onPrimaryPressed: _openAppSettings,
            secondaryLabel: 'تحديث الحالة',
            onSecondaryPressed: _refreshStatus,
          );
        }

        if (!hasPermission) {
          return _PermissionPanel(
            icon: Icons.location_on,
            title: 'مطلوب صلاحية الموقع',
            message:
                'نستخدم موقعك لحساب اتجاه القبلة. الرجاء منح الإذن للمتابعة.',
            primaryLabel: 'منح الإذن',
            onPrimaryPressed: _requestPermission,
            secondaryLabel: 'تحديث الحالة',
            onSecondaryPressed: _refreshStatus,
          );
        }

        return SafeArea(
          child: StreamBuilder(
            stream: FlutterQiblah.qiblahStream,
            builder: (context, snapshot) {
              if (snapshot.hasError || snapshot.data == null) {
                return _PermissionPanel(
                  icon: Icons.explore_off,
                  title: 'تعذر تحديد الاتجاه',
                  message: 'حاول مرة أخرى أو تأكد من تفعيل المستشعرات.',
                  primaryLabel: 'تحديث',
                  onPrimaryPressed: _refreshStatus,
                );
              }

              final qiblahDirection = snapshot.data;
              final qiblahAngle = qiblahDirection!.qiblah; // 0-360

              // Align Logic
              double normalizedAngle = qiblahAngle.abs() % 360;
              if (normalizedAngle > 180) {
                normalizedAngle = 360 - normalizedAngle;
              }
              final isAligned = normalizedAngle <= _alignmentThreshold;

              // Vibrate (Side Effect in Builder - handled carefully with postFrame)
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (isAligned && !_wasAligned) {
                  if (await Vibration.hasVibrator()) {
                    Vibration.vibrate();
                  }
                  if (mounted) setState(() => _wasAligned = true);
                } else if (!isAligned && _wasAligned) {
                  if (mounted) setState(() => _wasAligned = false);
                }
              });

              if (_animationController != null) {
                animation = Tween(
                  begin: begin,
                  end: -qiblahAngle, // Counter-rotate compass
                ).animate(_animationController!);
                begin = -qiblahAngle;
                _animationController!.forward(from: 0);
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // The Compass
                          Transform.rotate(
                            angle: (animation?.value ?? 0) * (pi / 180),
                            child: SvgPicture.asset(
                              'assets/svgs/compass_dial.svg',
                            ),
                          ),

                          CustomPaint(
                            size: MediaQuery.of(context).size * 0.8,
                            painter: CompassCustomPainter(
                              angle: animation?.value ?? 0,
                            ),
                            child: SizedBox(
                              width: 300.w,
                              height: 300.w,
                              child: Center(
                                child: Image.asset(
                                  AppImages.imagesKaaba,
                                  width: 50.w,
                                  height: 50.w,
                                ),
                              ),
                            ),
                          ),

                          // The Needle / Indicator
                          Positioned(
                            top: -40.h,
                            child: Icon(
                              Icons.expand_less_rounded,
                              color: isAligned ? Colors.red : Colors.grey,
                              size: 50.sp,
                              shadows: isAligned
                                  ? [
                                      const BoxShadow(
                                        color: Colors.red,
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  const _PermissionPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.green),
            SizedBox(height: 16.h),
            Text(
              title,
              style: AppStyles.style22u.copyWith(color: context.primaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              style: AppStyles.style16.copyWith(color: context.primaryColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                ),
                onPressed: onPrimaryPressed,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.isTablet ? 8 : 0,
                  ),
                  child: Text(
                    primaryLabel,
                    style: AppStyles.style16.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            if (secondaryLabel != null && onSecondaryPressed != null) ...[
              SizedBox(height: 10.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondaryPressed,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: context.isTablet ? 8 : 0,
                    ),
                    child: Text(
                      secondaryLabel!,
                      style: AppStyles.style16.copyWith(
                        color: context.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
