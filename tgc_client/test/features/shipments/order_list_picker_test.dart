import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/shipments/domain/entities/shipment_import_entities.dart';
import 'package:tgc_client/features/shipments/domain/repositories/shipment_repository.dart';
import 'package:tgc_client/features/shipments/domain/usecases/get_shipment_import_clients_usecase.dart';
import 'package:tgc_client/features/shipments/domain/usecases/get_shipment_import_items_usecase.dart';
import 'package:tgc_client/features/shipments/presentation/bloc/shipment_import_bloc.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/order_list_picker_sheet.dart';

/// Answers the two calls the picker makes; nothing else is reached.
class _FakeRepo implements ShipmentRepository {
  _FakeRepo(this.lines);
  final List<ShipmentImportItemEntity> lines;
  String? askedQuality = 'not asked';

  @override
  Future<Either<Failure, List<ShipmentImportItemEntity>>> getShipmentImportItems({
    required int clientId,
    String? qualityName,
  }) async {
    askedQuality = qualityName;
    return Right(lines);
  }

  @override
  Future<Either<Failure, List<ShipmentImportClientEntity>>> getShipmentImportClients() async =>
      const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ShipmentImportItemEntity _line(
  int orderItemId,
  int variantId,
  String name, {
  required int width,
  required int length,
  required int remaining,
  String quality = 'LUXURY',
  int orderId = 1,
}) =>
    ShipmentImportItemEntity(
      orderItemId: orderItemId,
      variantId: variantId,
      productName: name,
      colorName: 'krem',
      qualityName: quality,
      sizeWidth: width,
      sizeLength: length,
      availableQuantity: remaining,
      orderRemaining: remaining,
      orderId: orderId,
    );

void main() {
  late _FakeRepo repo;

  setUp(() {
    // As the server sends them: by size, then name, then order date.
    repo = _FakeRepo([
      _line(1, 10, '6506', width: 200, length: 300, remaining: 2, orderId: 5),
      _line(2, 10, '6506', width: 200, length: 300, remaining: 3, orderId: 9),
      _line(3, 11, '7166', width: 200, length: 300, remaining: 1, quality: 'SILK'),
      _line(4, 12, '6506', width: 300, length: 400, remaining: 4),
    ]);
    sl.registerFactory(() => ShipmentImportBloc(
          getClientsUseCase: GetShipmentImportClientsUseCase(repo),
          getItemsUseCase: GetShipmentImportItemsUseCase(repo),
        ));
  });

  tearDown(() => sl.reset());

  /// Opens the sheet on the form's client; [onResult] gets what it returns.
  Future<void> open(
    WidgetTester tester, {
    Map<int, int> onForm = const {},
    void Function(OrderListPickResult?)? onResult,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await OrderListPickerSheet.show(
                context,
                client: const ShipmentImportClientEntity(
                    id: 1, shopName: 'A MIJOZ', region: 'Toshkent', itemCount: 0),
                onForm: onForm,
              );
              onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every carpet of the form\'s client, grouped by size', (tester) async {
    await open(tester);

    expect(repo.askedQuality, isNull, reason: 'every quality in one call');
    expect(find.text('A MIJOZ'), findsOneWidget, reason: 'straight to the form\'s client');
    expect(find.text('200×300'), findsOneWidget);
    expect(find.text('300×400'), findsOneWidget);
    expect(find.text('2 ta · 6 dona'), findsOneWidget, reason: 'two carpets of 200×300, 5 + 1 owed');
    // 6506 on two orders is one row.
    expect(find.textContaining('#5, #9 · qolgan 5 dona'), findsOneWidget);
    expect(find.text('Barchasi (3)'), findsOneWidget);
  });

  testWidgets('ticking, counting and confirming hands back the carpets', (tester) async {
    OrderListPickResult? result;
    // 300×400 is already all on the form.
    await open(tester, onForm: const {12: 4}, onResult: (r) => result = r);

    expect(find.text('Formada'), findsOneWidget, reason: 'what the form holds is not offered again');

    await tester.tap(find.textContaining('#5, #9'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ta mahsulot, 5 dona'), findsOneWidget, reason: 'starts at all that is owed');

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ta mahsulot, 4 dona'), findsOneWidget);

    // Only SILK: the 7166 row, which can be ticked on its own.
    // The test font is wide enough to push this chip past the edge.
    await tester.ensureVisible(find.text('SILK (1)', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SILK (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#5, #9'), findsNothing);
    await tester.tap(find.textContaining('qolgan 1 dona'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Qo\'shish'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final picked = {for (final s in result!.selections) s.item.variantId: s.quantity};
    expect(picked, {10: 4, 11: 1});
    final lines = result!.selections.first.item.openLines.map((l) => l.orderItemId);
    expect(lines, [1, 2], reason: 'both order lines, oldest first');
  });
}
