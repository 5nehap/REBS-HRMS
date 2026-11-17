import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/api_exception.dart';

class ApiProvider {
  late final Dio _dio;

  ApiProvider({String? baseUrl, Dio? dio}) {
    if (dio != null) {
      _dio = dio;
    } else {
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? AppConfig.defaultApiBaseUrl,
          connectTimeout: const Duration(
            milliseconds: AppConfig.connectTimeoutMs,
          ),
          receiveTimeout: const Duration(
            milliseconds: AppConfig.receiveTimeoutMs,
          ),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        _dio.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            error: true,
            logPrint: (obj) => debugPrint('[Dio] $obj'),
          ),
        );
      }
    }
  }

  Dio get client => _dio;

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: e.toString());
    }
  }

  ApiException _handleDioError(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final responseData = response?.data;

    // Structured debug logging for developers
    if (kDebugMode) {
      debugPrint(
        '[ApiProvider] DioError: type=${error.type}, code=$statusCode, url=${error.requestOptions.uri}, message=${error.message}',
      );
    }

    String message = 'An unexpected error occurred';
    List<String> validationErrors = [];
    String? conflictType;

    if (responseData is Map<String, dynamic>) {
      if (responseData['message'] != null) {
        message = responseData['message'].toString();
      } else if (responseData['error'] != null) {
        message = responseData['error'].toString();
      }

      if (responseData['conflictType'] != null) {
        conflictType = responseData['conflictType'].toString();
      }

      if (responseData['errors'] is List) {
        validationErrors = (responseData['errors'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } else if (responseData is String && responseData.isNotEmpty) {
      message = responseData;
    }

    // Timeouts
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return NetworkException(
        message:
            'The server is taking longer than expected. Your attendance is saved and will be retried.',
        statusCode: statusCode,
        data: responseData,
      );
    }

    // Connection errors / connection refused / socket failures
    final isConnectionError =
        error.type == DioExceptionType.connectionError ||
        (error.error != null &&
            (error.error.toString().contains('Connection refused') ||
                error.error.toString().contains('SocketException') ||
                error.error.toString().contains('Failed host lookup')));

    if (isConnectionError) {
      return NetworkException(
        message:
            'Unable to connect to the server. Your attendance is safely saved on this device.',
        statusCode: statusCode,
        data: responseData,
      );
    }

    switch (statusCode) {
      case 400:
        return ApiException(
          message: message,
          statusCode: 400,
          data: responseData,
        );
      case 409:
        return ConflictException(
          message: message,
          statusCode: 409,
          conflictType: conflictType,
          data: responseData,
        );
      case 422:
        return ValidationException(
          message: message,
          statusCode: 422,
          errors: validationErrors,
          data: responseData,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: 'Something went wrong on the server. Please try again later.',
          statusCode: statusCode ?? 500,
          data: responseData,
        );
      default:
        return ApiException(
          message: message,
          statusCode: statusCode,
          data: responseData,
        );
    }
  }
}
