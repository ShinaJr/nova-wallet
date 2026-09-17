import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class MockInterceptor extends Interceptor {
  static const _uuid = Uuid();

  static double injectedFailureRate = 0.0;

  static bool forceInsufficientFunds = false;

  static int _balanceKobo = 45750000;

  static void seedBalance(int kobo) => _balanceKobo = kobo;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future.delayed(const Duration(milliseconds: 700));

    if (injectedFailureRate > 0 &&
        (DateTime.now().microsecondsSinceEpoch % 100) / 100 <
            injectedFailureRate) {
      return handler.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 500),
        type: DioExceptionType.badResponse,
      ));
    }

    final path = options.path;
    final method = options.method.toUpperCase();

    if (path == '/wallet/balance' && method == 'GET') {
      return handler.resolve(_ok(options, {
        'balanceKobo': _balanceKobo,
        'accountName': 'Moses Adeyemi',
        'accountNumber': '3012345678',
      }));
    }

    if (path == '/wallet/transactions' && method == 'GET') {
      return handler.resolve(_ok(options, {'transactions': _mockTxns()}));
    }

    if (path == '/transfers' && method == 'POST') {
      final data = options.data as Map<String, dynamic>;
      if (forceInsufficientFunds) {
        return handler.reject(DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 402,
            data: {'message': 'Insufficient funds'},
          ),
          type: DioExceptionType.badResponse,
        ));
      }
      final idempotencyKey = data['idempotencyKey'] as String;
      final amountKobo = data['amountKobo'] as int;
      _balanceKobo -= amountKobo;
      return handler.resolve(_ok(options, {
        'transactionRef': 'TRF-${idempotencyKey.substring(0, 8).toUpperCase()}',
        'status': 'successful',
        'amountKobo': amountKobo,
        'recipientName': data['recipientName'],
      }));
    }

    if (path == '/savings/goals' && method == 'POST') {
      return handler.resolve(_ok(options, {
        'id': _uuid.v4(),
        'message': 'Goal created successfully',
      }));
    }

    if (path.startsWith('/savings/goals/') &&
        path.endsWith('/contribute') &&
        method == 'POST') {
      if (forceInsufficientFunds) {
        return handler.reject(DioException(
          requestOptions: options,
          response: Response(
            requestOptions: options,
            statusCode: 402,
            data: {'message': 'Insufficient funds'},
          ),
          type: DioExceptionType.badResponse,
        ));
      }
      final data = options.data as Map<String, dynamic>;
      _balanceKobo -= data['amountKobo'] as int;
      return handler
          .resolve(_ok(options, {'message': 'Contribution recorded'}));
    }

    if (path == '/security/name-enquiry' && method == 'GET') {
      final account = options.queryParameters['accountNumber'] as String? ?? '';
      return handler.resolve(_ok(options, {
        'accountNumber': account,
        'accountName': account.endsWith('0') ? 'Adaobi Okafor' : 'Emeka Nwosu',
      }));
    }

    return handler.resolve(_ok(options, {'message': 'ok'}));
  }

  Response<dynamic> _ok(RequestOptions options, Map<String, dynamic> data) {
    return Response(requestOptions: options, statusCode: 200, data: data);
  }

  List<Map<String, dynamic>> _mockTxns() => [
        {
          'id': 'mock-txn-adaobi-transfer',
          'description': 'Transfer to Adaobi Okafor',
          'amountKobo': 500000,
          'type': 'debit',
          'timestamp': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'referenceNumber': 'TRF-ABC12345',
        },
        {
          'id': 'mock-txn-salary',
          'description': 'Salary — Meridian Holdings',
          'amountKobo': 35000000,
          'type': 'credit',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'referenceNumber': 'SAL-SEP2026',
        },
        {
          'id': 'mock-txn-mtn-airtime',
          'description': 'MTN Airtime Top-up',
          'amountKobo': 100000,
          'type': 'debit',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'referenceNumber': 'AIR-XYZ789',
        },
        {
          'id': 'mock-txn-dstv',
          'description': 'DSTV Subscription',
          'amountKobo': 290000,
          'type': 'debit',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 3))
              .toIso8601String(),
        },
        {
          'id': 'mock-txn-emeka-transfer',
          'description': 'Transfer from Emeka Nwosu',
          'amountKobo': 2000000,
          'type': 'credit',
          'timestamp': DateTime.now()
              .subtract(const Duration(days: 5))
              .toIso8601String(),
          'referenceNumber': 'TRF-DEF56789',
        },
      ];
}
