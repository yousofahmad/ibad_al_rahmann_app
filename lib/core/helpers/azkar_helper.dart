import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/azkar/data/zekr_model.dart';

import '../../features/azkar/ui/azkar_sections_screen.dart';

class AzkarHelper {
  static List<ZekrModel>? morningAzkar, eveningAzkar, afterPrayingAzkar;
  static Future<List<ZekrModel>> getAzkar(AzkarSection section) async {
    switch (section) {
      case AzkarSection.morning:
        {
          morningAzkar ??= await _getAzkarList(AppConsts.morningAzkarJson);
          return morningAzkar!;
        }
      case AzkarSection.evening:
        eveningAzkar ??= await _getAzkarList(AppConsts.eveningAzkarJson);
        return eveningAzkar!;

      // case AfterPrayAzkarSection():
      //   afterPrayingAzkar ??= await _getAzkarList(
      //     AppConstants.afterPrayingAzkarJson,
      //   );
      //   return afterPrayingAzkar!;
      default:
        // Temporary handler as AzkarSection.afterPrayer not implemented
        return [];
    }
  }

  static Future<List<ZekrModel>> _getAzkarList(String jsonFile) async {
    String jsonString = await rootBundle.loadString(jsonFile);
    final jsonResponse = json.decode(jsonString);

    List azkarAsJson = jsonResponse['content'];

    return azkarAsJson.map((zekr) => ZekrModel.fromJson(zekr)).toList();
  }
}
