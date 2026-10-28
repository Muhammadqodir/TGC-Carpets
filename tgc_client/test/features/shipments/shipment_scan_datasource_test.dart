import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/core/error/exceptions.dart';
import 'package:tgc_client/features/shipments/data/datasources/shipment_remote_datasource.dart';

/// Answers every request with one canned response, the way prod does.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body, {this.contentType = 'application/json'});

  final int status;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ShipmentRemoteDataSourceImpl _source(int status, Object body,
    {String contentType = 'application/json'}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://erp.test/api/v1'))
    ..httpClientAdapter = _FakeAdapter(
      status,
      body is String ? body : jsonEncode(body),
      contentType: contentType,
    );
  return ShipmentRemoteDataSourceImpl(dio);
}

const _carpet = {
  'order_item_id': null,
  'variant_id': 1332,
  'product_name': '6506',
  'color_name': 'krem',
  'color_image_url': null,
  'quality_name': 'Sintetik',
  'type_name': null,
  'size_length': 300,
  'size_width': 200,
  'product_unit': 'piece',
  'edge_code': null,
  'edge_title': null,
  'stock_quantity': 0,
  'produced_for_client': 'AKRAM AKA',
  'production_batch_item_id': 11112,
  'reason': 'no_open_line',
};

void main() {
  test('an off-order carpet arrives as a 200 and becomes an add-anyway item', () async {
    final item = await _source(200, {
      'data': _carpet,
      'matched': false,
      'message': 'ochiq buyurtma topilmadi',
      'unmatched': _carpet,
    }).getShipmentScanItem(code: 'P1585 I11112', clientId: 10);

    expect(item.orderItemId, isNull);
    expect(item.producedForClient, 'AKRAM AKA');
    expect(item.unmatchedReason, 'no_open_line');
    expect(item.productionBatchItemId, 11112);
  });

  test('beyond the order is told apart from never ordered', () async {
    final item = await _source(200, {
      'data': {..._carpet, 'produced_for_client': null, 'reason': 'open_lines_full'},
    }).getShipmentScanItem(code: 'P1551 I10825', clientId: 10);

    expect(item.isBeyondOrder, isTrue);
    expect(item.isOnClientOrder, isFalse);
  });

  test('an unknown label reads as "not found", not as a validation error', () async {
    final call = _source(422, {
      'message': 'Mahsulot topilmadi.',
      'errors': {
        'label': ["Bu QR kod bo'yicha mahsulot topilmadi."],
      },
    }).getShipmentScanItem(code: 'P1 I2', clientId: 10);

    await expectLater(
      call,
      throwsA(isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 404)
          .having((e) => e.message, 'message', contains('P1 I2'))),
    );
  });

  test("nginx's own 404 page still surfaces as a readable error", () async {
    final call = _source(
      404,
      '<html><head><title>404 Not Found</title></head></html>',
      contentType: 'text/html',
    ).getShipmentScanItem(code: 'P1 I2', clientId: 10);

    await expectLater(
      call,
      throwsA(isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 404)),
    );
  });
}
