import 'package:dio/dio.dart';
import 'mock_interceptor.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://api.novapay.firstbank.ng', // swap in the real host
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: const {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(MockInterceptor());
  }
}
