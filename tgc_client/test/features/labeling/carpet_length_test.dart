import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/carpet_length.dart';
import 'package:tgc_client/features/labeling/domain/entities/labeling_item_entity.dart';
import 'package:tgc_client/features/labeling/domain/entities/print_history_entity.dart';

void main() {
  group('parseCarpetLengthMetres', () {
    test('reads metres with a dot or a comma as whole centimetres', () {
      expect(parseCarpetLengthMetres('28.7'), 2870);
      expect(parseCarpetLengthMetres('28,75'), 2875);
      expect(parseCarpetLengthMetres(' 30 '), 3000);
      expect(parseCarpetLengthMetres('0.5'), 50);
    });

    test('refuses anything that is not a positive length', () {
      for (final bad in ['', '0', '0.0', 'abc', '28.755', '-3', '28.', '.5', '1.2.3']) {
        expect(parseCarpetLengthMetres(bad), isNull, reason: bad);
      }
    });
  });

  group('carpetLengthError', () {
    test('allows up to 10 m either side of the nominal length', () {
      expect(carpetLengthError(2000, 3000), isNull);
      expect(carpetLengthError(4000, 3000), isNull);
      expect(carpetLengthError(1999, 3000), isNotNull);
      expect(carpetLengthError(4001, 3000), isNotNull);
      expect(carpetLengthError(null, 3000), isNotNull);
    });
  });

  test('formatCarpetLengthMetres is the inverse of parsing', () {
    for (final cm in [2870, 2875, 3000, 50, 2805]) {
      expect(parseCarpetLengthMetres(formatCarpetLengthMetres(cm)), cm);
    }
    expect(formatCarpetLengthMetres(2870), '28.7');
    expect(formatCarpetLengthMetres(2805), '28.05');
  });

  test('the label shows the real length, the filters the nominal one', () {
    const item = LabelingItemEntity(
      id: 1,
      batchId: 2,
      plannedQuantity: 3,
      producedQuantity: 0,
      variantId: 4,
      productName: 'K',
      sizeWidth: 400,
      sizeLength: 3000,
      hasVariableLength: true,
    );
    final roll = item.copyWith(actualLengthCm: 2870);

    expect(item.sizeLabel, '400×3000');
    expect(roll.sizeLabel, '400×2870');
    expect(roll.nominalSizeLabel, '400×3000');
    expect(roll.hasVariableLength, isTrue);
  });

  test('print history keeps the length, and old entries read without one', () {
    const entry = PrintHistoryEntity(
      variantId: 4,
      productName: 'K',
      sizeWidth: 400,
      sizeLength: 3000,
      batchId: 2,
      printedAt: 0,
      actualLengthCm: 2870,
    );
    final back = PrintHistoryEntity.fromJson(entry.toJson());
    expect(back.actualLengthCm, 2870);
    expect(back.sizeLabel, '400×2870');

    final old = PrintHistoryEntity.fromJson(
      (entry.toJson()..remove('actualLengthCm')),
    );
    expect(old.actualLengthCm, isNull);
    expect(old.sizeLabel, '400×3000');
  });
}
