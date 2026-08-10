import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
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

class _QiblahCompassState extends State<QiblahCompass>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Instance variables (were incorrectly declared as globals outside the class,
  // causing a stale-reference crash when navigating back then re-entering).
  Animation<double>? animation;
  AnimationController? _animationController;
  double begin = 0.0;

  bool hasPermission = false;
  bool serviceEnabled = true;
  bool permissionPermanentlyDenied = false;
  bool _wasAligned = false;
  static const double _alignmentThreshold = 2.0;

  bool? _deviceSupport;

  // Accuracy (in degrees) from the raw compass sensor — null = unsupported
  double? _accuracy;
  StreamSubscription<CompassEvent>? _accuracySub;

  Future<void> _refreshStatus() async {
    try {
      // Timeout prevents hanging forever on old Android OEM ROMs where
      // location APIs can block indefinitely.
      final service = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      final permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 5),
        onTimeout: () => LocationPermission.denied,
      );

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

    // Subscribe to raw compass events to get the accuracy reading
    _accuracySub = FlutterCompass.events?.listen((event) {
      final acc = event.accuracy;
      if (mounted && acc != null && acc >= 0) {
        setState(() => _accuracy = acc);
      }
    });
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
    _accuracySub?.cancel();
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
            secondaryLabel: 'متابعة بدون موقع',
            onSecondaryPressed: () => setState(() => hasPermission = true),
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
                  // ── Accuracy Indicator ──────────────────────────────────
                  _buildAccuracyBadge(),
                  SizedBox(height: 8.h),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ── Accuracy Badge ──────────────────────────────────────────────────────────
extension _AccuracyBadge on _QiblahCompassState {
  /// _accuracy is the sensor's estimated heading error in degrees.
  /// Android returns: 0-15 = high, 15-30 = medium, >30 = low / needs calibration.
  /// null / -1 = unavailable.
  Widget _buildAccuracyBadge() {
    final acc = _accuracy;

    final Color color;
    final String label;
    final IconData icon;
    final bool needsCalibration;

    if (acc == null) {
      color = Colors.grey;
      label = 'دقة البوصلة: غير متاحة';
      icon = Icons.help_outline;
      needsCalibration = false;
    } else if (acc <= 15) {
      color = const Color(0xFF4CAF50); // green
      label = 'دقة البوصلة: قوية';
      icon = Icons.gps_fixed;
      needsCalibration = false;
    } else if (acc <= 30) {
      color = const Color(0xFFFFA726); // orange
      label = 'دقة البوصلة: معتدلة';
      icon = Icons.gps_not_fixed;
      needsCalibration = true;
    } else {
      color = const Color(0xFFEF5350); // red
      label = 'دقة البوصلة: ضعيفة — تحتاج معايرة';
      icon = Icons.gps_off;
      needsCalibration = true;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accuracy chip
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16.sp),
                SizedBox(width: 6.w),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.sp,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Calibration hint
          if (needsCalibration) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '∞',
                    style: TextStyle(
                      fontSize: 20.sp,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      'حرّك جهازك بشكل ∞ (لا نهاية) في الهواء لمعايرة البوصلة',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.sp,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: AppColors.green),
                SizedBox(height: 16.h),
                Text(
                  title,
                  style: AppStyles.style22u.copyWith(
                    color: context.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  style: AppStyles.style16.copyWith(
                    color: context.primaryColor,
                  ),
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
        ),
      ),
    );
  }
}
