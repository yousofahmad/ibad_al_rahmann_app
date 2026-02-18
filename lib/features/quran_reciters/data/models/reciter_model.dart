import 'package:ibad_al_rahmann/core/networking/api_keys.dart';

class ReciterMoshaf {
  final int id, surahTotal;
  final String name, server;
  final List<int> surahList;

  ReciterMoshaf({
    required this.id,
    required this.surahTotal,
    required this.name,
    required this.server,
    required this.surahList,
  });

  factory ReciterMoshaf.fromJson(Map<String, dynamic> json) {
    final String surahListData = json[ApiKeys.surahList];
    return ReciterMoshaf(
      id: json[ApiKeys.id],
      name: json[ApiKeys.name],
      surahTotal: json[ApiKeys.surahTotal],
      server: json[ApiKeys.server],
      surahList: surahListData.split(',').map((e) => int.parse(e)).toList(),
    );
  }
}

class ReciterModel {
  final int id;
  final String name;
  final List<ReciterMoshaf> moshafList;

  ReciterModel({
    required this.id,
    required this.name,
    required this.moshafList,
  });

  factory ReciterModel.fromJson(Map<String, dynamic> json) {
    // String? handleStyle(String? style) {
    //   if (style == 'Mujawwad') {
    //     return 'مجود';
    //   } else if (style == 'Murattal') {
    //     return 'مرتل';
    //   } else if (style == 'Muallim') {
    //     return 'مُعلم';
    //   } else {
    //     return null;
    //   }
    // }

    // return ReciterModel(
    //   id: json[ApiKeys.id],
    //   name: json[ApiKeys.translatedName][ApiKeys.name],
    //   style: handleStyle(json[ApiKeys.style]),
    // );
    final List moshafListData = json[ApiKeys.moshaf];
    return ReciterModel(
      id: json[ApiKeys.id],
      name: json[ApiKeys.name],
      moshafList: moshafListData.map((e) => ReciterMoshaf.fromJson(e)).toList(),
    );
  }
}
