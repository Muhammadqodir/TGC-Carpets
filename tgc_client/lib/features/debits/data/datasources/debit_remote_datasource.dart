import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/paginated_response.dart';
import '../models/client_debit_model.dart';
import '../models/debit_ledger_entry_model.dart';

abstract class DebitRemoteDataSource {
  Future<PaginatedResponse<ClientDebitModel>> getClientDebits({
    String? search,
    String? region,
    bool hasBalance = false,
    int page = 1,
    int perPage = 20,
  });

  Future<({
    ClientDebitModel client,
    Map<String, double> summary,
    List<DebitLedgerEntryModel> ledger,
  })> getClientDebitLedger(int clientId);
}

class DebitRemoteDataSourceImpl implements DebitRemoteDataSource {
  final Dio _dio;

  const DebitRemoteDataSourceImpl(this._dio);

  @override
  Future<PaginatedResponse<ClientDebitModel>> getClientDebits({
    String? search,
    String? region,
    bool hasBalance = false,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.clientDebits,
        queryParameters: {
          'page':     page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
          if (region != null && region.isNotEmpty) 'region': region,
          if (hasBalance) 'has_balance': 1,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final dataList = (body['data'] as List)
          .map((e) => ClientDebitModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;

      return PaginatedResponse<ClientDebitModel>(
        data:        dataList,
        currentPage: meta['current_page'] as int,
        lastPage:    meta['last_page'] as int,
        perPage:     meta['per_page'] as int,
        total:       meta['total'] as int,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<({
    ClientDebitModel client,
    Map<String, double> summary,
    List<DebitLedgerEntryModel> ledger,
  })> getClientDebitLedger(int clientId) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.clientDebitLedger(clientId),
      );

      final body = response.data as Map<String, dynamic>;

      final rawClient  = body['client'] as Map<String, dynamic>;
      final rawSummary = body['summary'] as Map<String, dynamic>;
      final rawLedger  = body['ledger'] as List;

      // The client block from the ledger endpoint doesn't have debit fields,
      // so we synthesise them from the summary.
      final clientModel = ClientDebitModel(
        id:          rawClient['id'] as int,
        uuid:        rawClient['uuid'] as String,
        contactName: rawClient['contact_name'] as String,
        phone:       rawClient['phone'] as String,
        shopName:    rawClient['shop_name'] as String,
        region:      rawClient['region'] as String,
        totalDebit:  (rawSummary['total_debit'] as num).toDouble(),
        totalCredit: (rawSummary['total_credit'] as num).toDouble(),
        balance:     (rawSummary['balance'] as num).toDouble(),
      );

      final summary = <String, double>{
        'total_debit':  (rawSummary['total_debit'] as num).toDouble(),
        'total_credit': (rawSummary['total_credit'] as num).toDouble(),
        'balance':      (rawSummary['balance'] as num).toDouble(),
      };

      final ledger = rawLedger
          .map((e) => DebitLedgerEntryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return (client: clientModel, summary: summary, ledger: ledger);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Never _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      throw NetworkException('Tarmoq xatosi. Internet aloqasini tekshiring.');
    }
    final code = e.response?.statusCode;
    if (code == 401) throw const UnauthorizedException();
    final message =
        (e.response?.data as Map<String, dynamic>?)?['message'] as String? ??
            e.message ??
            'Server xatosi';
    throw ServerException(message: message, statusCode: code);
  }
}
