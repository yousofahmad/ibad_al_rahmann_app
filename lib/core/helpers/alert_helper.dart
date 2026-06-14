import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:toastification/toastification.dart';

import '../../core/theme/app_styles.dart';

class AlertHelper {
  static void showWarningAlert(
    BuildContext context, {
    required String message,
  }) {
    toastification.show(
      context: context,
      alignment: Alignment.bottomRight,
      type: ToastificationType.warning,
      direction: TextDirection.rtl,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text(
        message,
        style: context.isTablet
            ? AppStyles.style14harmattan.copyWith(color: Colors.black)
            : AppStyles.style20,
      ),
    );
  }

  static void showErrorAlert(BuildContext context, {required String message}) {
    toastification.show(
      context: context,
      alignment: Alignment.bottomRight,
      type: ToastificationType.error,
      direction: TextDirection.rtl,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text(
        message,
        style: context.isTablet
            ? AppStyles.style14harmattan.copyWith(color: Colors.black)
            : AppStyles.style20,
      ),
    );
  }

  static void showSuccessAlert(
    BuildContext context, {
    required String message,
  }) {
    toastification.show(
      context: context,
      alignment: Alignment.bottomRight,
      type: ToastificationType.success,
      direction: TextDirection.rtl,
      autoCloseDuration: const Duration(seconds: 2),
      title: Text(
        message,
        style: context.isTablet
            ? AppStyles.style14harmattan.copyWith(color: Colors.black)
            : AppStyles.style20,
      ),
    );
  }
}
