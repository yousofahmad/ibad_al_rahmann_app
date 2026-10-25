import 'package:flutter_test/flutter_test.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';

void main() {
  test('Digital Khatt page aliases identify one format but not QPC', () {
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_DIGITAL_KHATT_V2_P1',
        'IBAD_DIGITAL_KHATT_V2_P604',
      ),
      isTrue,
    );
    expect(
      FontsHelper.sameFormatFamily('IBAD_DIGITAL_KHATT_V2_P1', 'QCF_V1_P1'),
      isFalse,
    );
    expect(FontsHelper.sameFormatFamily('QCF_V1_P1', 'QCF_V1_P604'), isTrue);
  });

  test('malformed or non-page families are rejected', () {
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_DIGITAL_KHATT_V2',
        'IBAD_DIGITAL_KHATT_V2_P1',
      ),
      isFalse,
    );
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_DIGITAL_KHATT_V2_P0',
        'IBAD_DIGITAL_KHATT_V2_P1',
      ),
      isFalse,
    );
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_DIGITAL-KHATT_V2_P1',
        'IBAD_DIGITAL-KHATT_V2_P2',
      ),
      isFalse,
    );
    expect(
      FontsHelper.sameFormatFamily(
        'IBAD_DIGITAL_KHATT_V2_P1.ttf',
        'IBAD_DIGITAL_KHATT_V2_P2',
      ),
      isFalse,
    );
  });
}
