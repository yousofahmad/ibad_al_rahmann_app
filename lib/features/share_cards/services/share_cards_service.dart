import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ibad_al_rahmann/features/share_cards/models/share_card_model.dart';

class ShareCardsService {
  static const String _baseUrl =
      "https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/main/";
  static const String _configPath = "app_config.json";

  final Dio _dio = Dio();

  Future<List<ShareCardCategory>> fetchShareCards() async {
    try {
      final response = await _dio.get("$_baseUrl$_configPath");
      if (response.statusCode == 200) {
        final data = response.data is String
            ? jsonDecode(response.data)
            : response.data;
        
        List<dynamic> cardsJson;
        if (data is List) {
          // Fallback if the user put share_cards directly as a list at root (unlikely given current logic but good for safety)
          cardsJson = data;
        } else if (data is Map && data.containsKey('share_cards')) {
          cardsJson = data['share_cards'];
        } else {
          return [];
        }

        return cardsJson.map((c) => ShareCardCategory.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching share cards: $e");
      return [];
    }
  }

  String getFullImageUrl(String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    return "$_baseUrl$relativeUrl";
  }
}
