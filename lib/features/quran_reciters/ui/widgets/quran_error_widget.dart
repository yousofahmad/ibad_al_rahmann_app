
import 'package:flutter/material.dart';

import '../../../../core/theme/app_styles.dart';

class QurraaErrorWidget extends StatelessWidget {
  const QurraaErrorWidget({super.key, required this.error});

  final String error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        error,
        style: AppStyles.style20.copyWith(color: Colors.red),
      ),
    );
  }
}
