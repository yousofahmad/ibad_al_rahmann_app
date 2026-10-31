import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/features/share_cards/services/share_cards_service.dart';

class _ConfigAdapter implements HttpClientAdapter {
  _ConfigAdapter(this.config);

  final Map<String, dynamic> config;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(
      Stream<Uint8List>.value(
        Uint8List.fromList(utf8.encode(jsonEncode(config))),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('loads old and newly added cards from the resources branch', () async {
    final adapter = _ConfigAdapter({
      'share_cards': [
        {
          'category': 'رمضان',
          'items': [
            {'title': 'بطاقة 1', 'url': 'images/share_cards/ramadan_1.png'},
            {'title': 'بطاقة 4', 'url': 'images/share_cards/ramadan_4.png'},
          ],
        },
        {
          'category': 'الأذكار',
          'items': [
            {
              'title': 'أذكار الصباح',
              'url': 'images/share_cards/adhkar_morning_wide_v3.png',
            },
          ],
        },
      ],
    });
    final service = ShareCardsService(dio: Dio()..httpClientAdapter = adapter);

    final categories = await service.fetchShareCards();

    expect(
      adapter.request.uri.toString(),
      startsWith(
        'https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/source/import-qul-resources/',
      ),
    );
    expect(adapter.request.uri.toString(), endsWith('/app_config.json'));
    expect(categories, hasLength(2));
    expect(
      categories.first.items.map((item) => item.title),
      containsAll(<String>['بطاقة 1', 'بطاقة 4']),
    );
    expect(categories.last.items.single.title, 'أذكار الصباح');
    expect(
      service.getFullImageUrl(categories.last.items.single.url),
      'https://raw.githubusercontent.com/yousofahmad/ibad-alrahman-features/source/import-qul-resources/images/share_cards/adhkar_morning_wide_v3.png',
    );
  });
}
