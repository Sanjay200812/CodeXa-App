import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../storage/secure_storage.dart';

class CxApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;

  CxApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  @override
  String toString() => message;
}

class CxApiClient {
  static final CxApiClient _instance = CxApiClient._internal();
  factory CxApiClient() => _instance;

  late final Dio dio;

  // Authoritative production backend: https://codxa-agency.online
  // Overridable via --dart-define=API_BASE_URL=...
  static const String _defaultUrl = 'https://codxa-agency.online';
  static const String _envUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultUrl,
  );

  late String baseUrl;

  CxApiClient._internal() {
    baseUrl = _sanitizeUrl(_envUrl);

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-app-version': '1.0.0',
          'x-platform': 'ANDROID',
        },
      ),
    );

    if (kDebugMode) {
      final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
      debugPrint('[AUTH_STAGE_1] app config loaded');
      debugPrint('[AUTH] API HOST: $host');
    }

    _setupInterceptors();
  }

  static String _sanitizeUrl(String url) {
    String clean = url.trim();
    if (clean.isEmpty) clean = _defaultUrl;
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    // Prevent /api trailing duplication
    if (clean.endsWith('/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    return clean;
  }

  void setBaseUrl(String newUrl) {
    baseUrl = _sanitizeUrl(newUrl);
    dio.options.baseUrl = baseUrl;
    if (kDebugMode) {
      final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
      debugPrint('[AUTH] Updated API HOST: $host');
    }
  }

  void updateBaseUrl(String newUrl) => setBaseUrl(newUrl);

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await CxStorage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            final deviceId = await CxStorage.getOrCreateDeviceId();
            options.headers['x-device-id'] = deviceId;
          } catch (storageErr) {
            debugPrint('[API onRequest] storage read notice: $storageErr');
          }

          return handler.next(options);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) {
            debugPrint(
              '[API ERROR] ${e.requestOptions.method} ${e.requestOptions.path} '
              'type=${e.type} status=${e.response?.statusCode} msg=${e.message} error=${e.error}',
            );
          }

          String code = 'NETWORK_ERROR';
          String message = 'Check your internet connection.';
          String? reqId;
          final int? status = e.response?.statusCode;

          if (e.response != null) {
            final data = e.response?.data;
            if (data is Map<String, dynamic>) {
              reqId = data['requestId']?.toString();
              if (data['error'] is Map) {
                code = data['error']['code'] ?? 'API_ERROR';
                message = data['error']['message'] ?? 'An error occurred.';
              } else if (data['error'] is String) {
                message = data['error'];
              } else if (data['message'] is String) {
                message = data['message'];
              }
            }

            // Specific HTTP status code mappings per CodeXa specifications
            if (status == 503 || code == 'DATABASE_UNAVAILABLE') {
              code = 'DATABASE_UNAVAILABLE';
              message =
                  'CodeXa is temporarily unable to connect to its database.';
            } else if (status == 500) {
              code = 'INTERNAL_SERVER_ERROR';
              message = 'CodeXa encountered a server error.';
            } else if (status == 401) {
              if (code == 'INVALID_CREDENTIALS') {
                message = 'Incorrect login details.';
              } else {
                code = 'UNAUTHORIZED';
                message = 'Incorrect login details or session expired.';
              }
            } else if (status == 403) {
              code = 'ACCOUNT_DISABLED';
              message = 'Your CodeXa account is disabled.';
            } else if (status == 404) {
              code = 'NOT_FOUND';
              message =
                  'Requested service route was not found on CodeXa servers.';
            }
          } else if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            code = 'TIMEOUT';
            message = 'Connection timed out. Check your internet connection.';
          } else if (e.type == DioExceptionType.connectionError) {
            code = 'CONNECTION_ERROR';
            message = 'Unable to connect to CodeXa servers. Check your internet connection.';
          } else if (e.type == DioExceptionType.badCertificate) {
            code = 'SSL_ERROR';
            message = 'Secure connection could not be established.';
          } else if (e.type == DioExceptionType.unknown && e.error != null) {
            final errStr = e.error.toString();
            if (errStr.contains('SocketException') ||
                errStr.contains('Failed host lookup')) {
              code = 'CONNECTION_ERROR';
              message = 'Unable to reach CodeXa servers. Check your cellular data or Wi-Fi.';
            } else if (errStr.contains('HandshakeException')) {
              code = 'SSL_ERROR';
              message = 'Secure handshake failed. Check your network or VPN settings.';
            } else {
              code = 'CLIENT_ERROR';
              message = e.message?.isNotEmpty == true
                  ? e.message!
                  : 'Network communication error.';
            }
          }

          if (status == 401 &&
              !e.requestOptions.path.contains('/auth/login') &&
              !e.requestOptions.path.contains('/auth/refresh') &&
              e.requestOptions.extra['retried_after_refresh'] != true) {
            e.requestOptions.extra['retried_after_refresh'] = true;
            _refreshTokenSingleFlight()
                .then((newToken) async {
                  if (newToken != null && newToken.isNotEmpty) {
                    e.requestOptions.headers['Authorization'] =
                        'Bearer $newToken';
                    try {
                      final retryRes = await dio.fetch(e.requestOptions);
                      return handler.resolve(retryRes);
                    } catch (retryErr) {
                      if (retryErr is DioException) {
                        return handler.reject(retryErr);
                      }
                    }
                  }
                  _rejectStandardError(
                    e,
                    handler,
                    code,
                    message,
                    status,
                    reqId,
                  );
                })
                .catchError((_) {
                  _rejectStandardError(
                    e,
                    handler,
                    code,
                    message,
                    status,
                    reqId,
                  );
                });
            return;
          }

          _rejectStandardError(e, handler, code, message, status, reqId);
        },
      ),
    );
  }

  void _rejectStandardError(
    DioException e,
    ErrorInterceptorHandler handler,
    String code,
    String message,
    int? status,
    String? reqId,
  ) {
    handler.reject(
      DioException(
        requestOptions: e.requestOptions,
        error: CxApiException(
          code: code,
          message: message,
          statusCode: status,
          requestId: reqId,
        ),
        response: e.response,
        type: e.type,
        message: message,
      ),
    );
  }

  static Future<String?>? _refreshFuture;

  Future<String?> _refreshTokenSingleFlight() async {
    if (_refreshFuture != null) {
      return _refreshFuture;
    }
    _refreshFuture = _doRefreshToken();
    try {
      final res = await _refreshFuture;
      return res;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _doRefreshToken() async {
    try {
      final active = await CxStorage.getActiveAccount();
      if (active == null || active.accessToken.isEmpty) return null;

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
        ),
      );
      final res = await refreshDio.post(
        '/api/mobile/auth/refresh',
        data: {'refreshToken': active.accessToken},
        options: Options(
          headers: {'Authorization': 'Bearer ${active.accessToken}'},
        ),
      );

      if (res.data != null && res.data['ok'] == true) {
        final newToken =
            res.data['accessToken']?.toString() ?? active.accessToken;
        final user = res.data['user'] != null
            ? UserModel.fromJson(res.data['user'])
            : UserModel(
                id: active.id,
                username: active.username,
                email: active.email,
                fullName: active.fullName,
                role: active.role,
                orgRole: active.orgRole,
                department: active.department,
                profileMediaUrl: active.profileMediaUrl,
              );
        final updatedAccount = SavedAccount.fromUserAndToken(user, newToken);
        await CxStorage.saveAccount(updatedAccount, makeActive: true);
        return newToken;
      }
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[CxApiClient] Single-flight refresh notice: $err');
      }
    }
    return null;
  }

  static String parseError(dynamic e) {
    if (e is DioException) {
      if (e.error is CxApiException) {
        return (e.error as CxApiException).message;
      }
      final status = e.response?.statusCode;
      if (status == 503) {
        return 'CodeXa is temporarily unable to connect to its database.';
      } else if (status == 500) {
        return 'CodeXa encountered a server error.';
      } else if (status == 401) {
        return 'Incorrect login details.';
      } else if (status == 403) {
        return 'Your CodeXa account is disabled.';
      } else if (status == 404) {
        return 'CodeXa server route not found.';
      }

      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        if (data['error'] is Map) {
          return data['error']['message'] ?? 'An error occurred.';
        } else if (data['error'] is String) {
          return data['error'];
        } else if (data['message'] is String) {
          return data['message'];
        }
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return 'Connection timed out. Check your internet connection.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Check your internet connection.';
      }
      if (e.message != null && e.message!.isNotEmpty && e.message != 'null') {
        return e.message!;
      }
      return 'Server error (${status ?? "Network"}).';
    } else if (e is CxApiException) {
      return e.message;
    }
    final raw = e?.toString() ?? '';
    if (raw.isEmpty ||
        raw == 'null' ||
        raw.contains('DioException [bad response]: null')) {
      return 'CodeXa encountered a server error.';
    }
    return raw;
  }
}
