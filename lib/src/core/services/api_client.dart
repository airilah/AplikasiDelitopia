import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

// Provider for Dio instance
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

  if (!kIsWeb && kDebugMode) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Allow self-signed certificate overrides exclusively during local debugging
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  // Add interceptors
  dio.interceptors.add(AuthInterceptor(ref));
  if (kDebugMode) {
    dio.interceptors.add(LoggingInterceptor());
  }

  return dio;
});

// Auth interceptor to add JWT token
class AuthInterceptor extends Interceptor {
  final Ref ref;

  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(storageServiceProvider).getAuthToken();
    if (kDebugMode) {
      print(
          '🔑 AuthInterceptor - Token: ${token != null ? "${token.substring(0, token.length > 20 ? 20 : token.length)}..." : "null"}');
    }
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        print('✅ AuthInterceptor - Added Authorization header');
      }
    } else {
      if (kDebugMode) {
        print('⚠️ AuthInterceptor - No token available');
      }
    }
    handler.next(options);
  }
}

// Logging interceptor for debugging
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('🌐 REQUEST[${options.method}] => ${options.uri}');
      if (options.data != null) {
        print('📤 REQUEST BODY => ${options.data}');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print(
          '✅ RESPONSE[${response.statusCode}] => ${response.requestOptions.uri}');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final code = err.response?.statusCode != null
          ? '${err.response?.statusCode}'
          : err.type.name;
      print('❌ ERROR[$code] => ${err.requestOptions.uri}');
      if (err.message != null && err.message!.isNotEmpty) {
        print('   Details: ${err.message}');
      }
      if (err.response?.data != null) {
        print('📥 ERROR RESPONSE DATA => ${err.response?.data}');
      }
    }
    super.onError(err, handler);
  }
}

// API Client with common methods
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // GET request with automatic retry for transient network issues
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    int maxRetries = 2,
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await _dio.get(
          path,
          queryParameters: queryParameters,
        );
        return _handleResponse(response);
      } on DioException catch (e) {
        final isTransient = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (e.response?.statusCode != null && e.response!.statusCode! >= 500);

        if (isTransient && attempts <= maxRetries) {
          final delayMs = 400 * attempts;
          if (kDebugMode) {
            print(
                '🔄 [ApiClient] Retrying GET $path in ${delayMs}ms (attempt $attempts/$maxRetries due to ${e.type.name})');
          }
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        throw _handleError(e);
      }
    }
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool isMultipart = false,
  }) async {
    try {
      dynamic requestData = data;

      // Convert to FormData if multipart
      if (isMultipart && data is Map<String, dynamic>) {
        requestData = FormData.fromMap(data);
      }

      final response = await _dio.post(
        path,
        data: requestData,
        queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // DELETE request
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Handle response
  Map<String, dynamic> _handleResponse(Response response) {
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      return response.data as Map<String, dynamic>;
    } else {
      throw ApiException(
        message: 'Request failed with status: ${response.statusCode}',
        statusCode: response.statusCode);
    }
  }

  // Handle errors
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Connection timeout. Please check your internet connection.',
          statusCode: 408);
      case DioExceptionType.badCertificate:
        return ApiException(
          message:
              'Sertifikat HTTPS server tidak dipercaya. Perbaiki SSL certificate di server aplikasi.mannagroup.id.',
          statusCode: 495);
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 500;
        final responseData = error.response?.data;
        final message = responseData != null
            ? _extractErrorMessage(responseData)
            : 'Something went wrong';
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: responseData is Map<String, dynamic> ? responseData : null);
      case DioExceptionType.cancel:
        return ApiException(message: 'Request cancelled', statusCode: 499);
      case DioExceptionType.connectionError:
        final detail = error.message?.toLowerCase() ?? '';
        if (detail.contains('certificate') ||
            detail.contains('handshake') ||
            detail.contains('ssl') ||
            detail.contains('trust')) {
          return ApiException(
            message:
                'Koneksi HTTPS gagal karena sertifikat server tidak dipercaya. Perbaiki SSL certificate di server aplikasi.mannagroup.id.',
            statusCode: 495);
        }
        return ApiException(
          message: 'Tidak bisa terhubung ke server. Periksa koneksi internet.',
          statusCode: 0);
      default:
        return ApiException(
          message: 'Network error. Please check your connection.',
          statusCode: 0);
    }
  }

  String _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      final errors = data['errors'];
      final shouldPreferFieldError =
          message == null || message.toLowerCase() == 'validation failed';

      if (shouldPreferFieldError && errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value != null) {
            return value.toString();
          }
        }
      }
      return message ?? 'Something went wrong';
    }
    
    // If data is HTML (e.g. Laravel 500 debug page), extract exception or return first 200 chars
    final strData = data.toString();
    if (strData.contains('<title>')) {
      final match = RegExp(r'<title>(.*?)</title>').firstMatch(strData);
      if (match != null) {
        return 'Server Error: ${match.group(1)}';
      }
    }
    return strData.length > 200 ? strData.substring(0, 200) : strData;
  }
}

// API Exception
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => message;
}

// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});
