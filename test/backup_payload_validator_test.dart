import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/services/backup_payload_validator.dart';

void main() {
  test(
    'unknown schemas and version-only documents are not restorable backups',
    () {
      for (final version in [true, 1, '2.0.0', 'garbage', '']) {
        expect(
          BackupPayloadValidator.isValid({'version': version, 'bookmarks': []}),
          isFalse,
        );
      }
      expect(BackupPayloadValidator.isValid({'version': '1.2.0'}), isFalse);
      expect(
        BackupPayloadValidator.isValid({'version': '1.2.0', 'bookmarks': []}),
        isTrue,
      );
      expect(
        BackupPayloadValidator.isValid({
          'version': '1.0.0',
          'preferences': <String, dynamic>{},
        }),
        isTrue,
      );
    },
  );

  test(
    'bookmark verse must actually exist in its surah before restore starts',
    () {
      Map<String, dynamic> payload(int surah, num verse) => {
        'version': '1.2.0',
        'bookmarks': [
          {
            'surahNumber': surah,
            'verseNumber': verse,
            'bookmarkedAt': '2026-01-01T00:00:00Z',
          },
        ],
      };
      expect(BackupPayloadValidator.isValid(payload(1, 7)), isTrue);
      expect(BackupPayloadValidator.isValid(payload(1, 8)), isFalse);
      expect(BackupPayloadValidator.isValid(payload(2, 286)), isTrue);
      expect(BackupPayloadValidator.isValid(payload(2, 287)), isFalse);
      expect(BackupPayloadValidator.isValid(payload(114, 7)), isFalse);
      expect(BackupPayloadValidator.isValid(payload(0, 1)), isFalse);
      expect(BackupPayloadValidator.isValid(payload(2, 1.5)), isFalse);
    },
  );

  test(
    'non-finite settings are rejected instead of being written to preferences',
    () {
      for (final value in [
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          BackupPayloadValidator.isValid({
            'version': '1.2.0',
            'preferences': {'latitude': value},
          }),
          isFalse,
        );
      }
    },
  );

  test('rejects malformed bookmark before restore can clear local data', () {
    final payload = <String, dynamic>{
      'version': '1.2.0',
      'preferences': <String, dynamic>{'theme': 'dark'},
      'bookmarks': <dynamic>[
        {
          'surahNumber': 2,
          'verseNumber': 'not-a-number',
          'bookmarkedAt': '2025-01-01T00:00:00Z',
        },
      ],
      'khatmas': <String, dynamic>{},
    };

    expect(BackupPayloadValidator.isValid(payload), isFalse);
  });

  test('accepts a valid payload and rejects invalid top-level sections', () {
    final valid = <String, dynamic>{
      'version': '1.2.0',
      'preferences': <String, dynamic>{
        'enabled': true,
        'days': <dynamic>['1', null],
      },
      'bookmarks': <dynamic>[
        {
          'surahNumber': 2,
          'verseNumber': 255,
          'bookmarkedAt': '2025-01-01T00:00:00Z',
        },
      ],
      'khatmas': <String, dynamic>{'khatma_1': 3},
    };

    expect(BackupPayloadValidator.isValid(valid), isTrue);
    expect(
      BackupPayloadValidator.isValid({...valid, 'preferences': 'bad'}),
      isFalse,
    );
    expect(
      BackupPayloadValidator.isValid({...valid, 'bookmarks': 'bad'}),
      isFalse,
    );
  });
}
